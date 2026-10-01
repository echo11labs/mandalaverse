import os
from PIL import Image

def process_image(input_path, output_path):
    print(f"Processing {input_path}...")
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()

    new_data = []
    for item in data:
        # Change pure black (or very close) to transparent
        if item[0] < 25 and item[1] < 25 and item[2] < 25:
            # We preserve the color but make it fully transparent, or we can soften it
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Saved {output_path}")

crest = "/Users/devendrashahithakuri/.gemini/antigravity-ide/brain/24d0548c-56f3-43cc-9054-a0fd1488b191/ornate_crest_1790799580833.jpg"
minimap = "/Users/devendrashahithakuri/.gemini/antigravity-ide/brain/24d0548c-56f3-43cc-9054-a0fd1488b191/minimap_frame_1790799599795.jpg"

out_dir = "/Users/devendrashahithakuri/Work/Nep-All/game/assets/ui/theme/"
os.makedirs(out_dir, exist_ok=True)

process_image(crest, out_dir + "crest.png")
process_image(minimap, out_dir + "minimap_frame.png")
