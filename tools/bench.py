"""G1-12 replay runner; full measurements require a clean committed checkout."""
import argparse
import json
import math
from pathlib import Path
import platform
import re
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / '.tools/godot/Godot.app/Contents/MacOS/Godot'
ERROR = re.compile(r'(?:SCRIPT ERROR:|(?:^|\n)ERROR:)')


def command_output(command):
    result = subprocess.run(command, capture_output=True, text=True)
    return {'exit_code': result.returncode, 'output': result.stdout.strip(), 'error': result.stderr.strip()}


def summarize(runs):
    groups = []
    for resolution in [(1280, 800), (1920, 1080)]:
        selected = [r for r in runs if tuple(r['resolution']) == resolution and r['vsync_requested'] == 'off']
        frame = [r['frame_ms']['p95'] for r in selected]
        tick = [r['tick_ms']['p95'] for r in selected]
        groups.append({'resolution': resolution, 'runs': len(selected), 'valid': bool(selected) and all(r['valid'] for r in selected),
                       'frame_p95_ms': frame, 'tick_p95_ms': tick,
                       'frame_p95_variance': statistics.pvariance(frame) if frame else None,
                       'tick_p95_variance': statistics.pvariance(tick) if tick else None,
                       'frame_p95_range': max(frame)-min(frame) if frame else None,
                       'frame_budget_ms': 16.7 if resolution[0] == 1280 else 20.0,
                       'tick_budget_ms': 4.0,
                       'meets_budget': bool(selected) and all(r['valid'] and r['frame_ms']['p95'] <= (16.7 if resolution[0] == 1280 else 20.0) and r['tick_ms']['p95'] <= 4 for r in selected)})
    return groups


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--smoke', action='store_true')
    parser.add_argument('--quick', action='store_true', help='Development only: one short rendered replay; never a baseline')
    parser.add_argument('--profile', action='store_true', help='Separate instrumented diagnostic replay, never used as baseline')
    parser.add_argument('--output', type=Path, default=ROOT/'reports/bench')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    revision = command_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'])['output']
    changes = command_output(['git','-C',str(ROOT),'status','--porcelain','--untracked-files=normal'])['output']
    # Reports are derived output; all game/tools/config changes must be committed.
    dirty = [line for line in changes.splitlines() if not line[3:].startswith('reports/')]
    if dirty and not (args.smoke or args.quick or args.profile):
        raise SystemExit('Full baseline needs a clean checkout. Uncommitted entries: '+str(dirty))
    warmup, duration = (0, 3) if args.smoke else ((1, 35) if args.quick or args.profile else (30, 120))
    jobs = [(1280,800,'off',1)] if args.smoke or args.quick or args.profile else [(w,h,mode,run) for w,h in [(1280,800),(1920,1080)] for mode,count in [('off',3),('on',1)] for run in range(1,count+1)]
    machine = {'platform':platform.platform(),'hardware':command_output(['sysctl','-n','hw.model','hw.memsize']),
               'power':command_output(['pmset','-g','batt']),'thermal':command_output(['pmset','-g','therm']),
               'process_load':command_output(['ps','-Ao','pcpu,comm']),
               'other_apps':'User-owned editor and applications left open; no unsolicited termination. Background CPU contention is not isolated.'}
    runs = []
    for width,height,vsync,index in jobs:
        stem = f'{width}x{height}-{vsync}-{index}'+('-profile' if args.profile else '')
        path = output/(stem+'.json')
        command = [str(ENGINE),'--path',str(ROOT/'game'),'--script','bench/run.gd','--resolution',f'{width}x{height}','--max-fps','0']
        if args.smoke: command += ['--headless']
        if vsync == 'off': command += ['--disable-vsync']
        if args.profile: command += ['--profiling','--debug']
        command += ['--',f'--width={width}',f'--height={height}',f'--vsync={vsync}',f'--warmup={warmup}',f'--duration={duration}',f'--smoke={str(args.smoke).lower()}',f'--output={path}']
        print('Starting '+stem, flush=True)
        started = time.monotonic()
        log = output/(stem+'.log')
        with log.open('w') as stream:
            completed = subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=warmup+duration+90)
        text = log.read_text(errors='replace')
        if completed.returncode or ERROR.search(text) or not path.exists() or 'GOPALA_TEST_REPORT=' not in text:
            raise SystemExit('Replay failed; inspect '+str(log))
        report = json.loads(path.read_text())
        report.update({'revision':revision,'wall_seconds':round(time.monotonic()-started,2),'log':log.name,'run':index,'baseline':not(args.smoke or args.quick or args.profile)})
        path.write_text(json.dumps(report,indent=2)+'\n')
        runs.append(report)
        print(f"Finished {stem}: valid={report['valid']} active_min={report['minimum_active']} frame_p95={report['frame_ms']['p95']:.2f}ms tick_p95={report['tick_ms']['p95']:.2f}ms",flush=True)
    summary = {'revision':revision,'machine':machine,'mode':'smoke' if args.smoke else 'profile' if args.profile else 'quick' if args.quick else 'baseline','groups':summarize(runs),'runs':runs,
               'regression_budget_percent':5,'regression_status':'Baseline only; comparison requires matching fixture, machine, resolution, vsync and camera protocol.'}
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    lines = ['# G1-12 benchmark',f"\nRevision: {revision}. Mode: {summary['mode']}.\n",'| Resolution | Vsync | Run | Valid | Active minimum | Frame median/p95/max ms | Tick median/p95/max ms |','|---|---|---|---|---|---|---|']
    for r in runs:
        f,t = r['frame_ms'],r['tick_ms']
        lines.append(f"| {r['resolution']} | {r['vsync_requested']} | {r['run']} | {r['valid']} | {r['minimum_active']} | {f['median']:.2f}/{f['p95']:.2f}/{f['max']:.2f} | {t['median']:.2f}/{t['p95']:.2f}/{t['max']:.2f} |")
    lines += ['\n'+json.dumps(summary['groups'],indent=2),'\nRaw reports include draw calls, rendered instances, memory, display, adapter, renderer, engine, activity windows and finite initial supplies. Frame intervals include main-thread stalls and presentation; they are not GPU-only durations. PNG readback frames are excluded.','\nInvalid workload runs remain listed and are not accepted for regression comparisons. Vsync-on references are separate from the three vsync-off runs. Profiling is separate because it changes timings.','\n## Suggestions\n\nRun with consistent power/thermal state and quiescent user apps; compare valid runs only. Profile any budget miss before adding addons.']
    (output/'SUMMARY.md').write_text('\n'.join(lines)+'\n')
    if args.smoke:
        valid = all(r['ok'] and r['fixture']['workers']==40 and r['fixture']['cattle']==2 and r['logical_ticks']>=8 for r in runs)
        print('GOPALA_TEST_REPORT='+json.dumps({'ok':valid,'checks':4,'failures':[] if valid else ['Benchmark smoke fixture failed']}))
        raise SystemExit(0 if valid else 1)

if __name__ == '__main__': main()
