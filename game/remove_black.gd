@tool
extends SceneTree

func _init():
	var paths = [
		"/Users/devendrashahithakuri/.gemini/antigravity-ide/brain/24d0548c-56f3-43cc-9054-a0fd1488b191/ornate_crest_1790799580833.jpg",
		"/Users/devendrashahithakuri/.gemini/antigravity-ide/brain/24d0548c-56f3-43cc-9054-a0fd1488b191/minimap_frame_1790799599795.jpg"
	]
	
	var out_names = ["crest.png", "minimap_frame.png"]
	
	for i in range(paths.size()):
		var img = Image.new()
		var err = img.load(paths[i])
		if err != OK:
			print("Failed to load ", paths[i])
			continue
			
		img.convert(Image.FORMAT_RGBA8)
		
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var c = img.get_pixel(x, y)
				# If pixel is very dark, make it fully transparent.
				# We can use a smooth threshold for anti-aliasing
				var brightness = (c.r + c.g + c.b) / 3.0
				if brightness < 0.1:
					# Fade out dark pixels
					c.a = clamp(brightness * 10.0, 0.0, 1.0)
					img.set_pixel(x, y, c)
		
		var out_path = "res://assets/ui/theme/" + out_names[i]
		img.save_png(out_path)
		print("Saved to ", out_path)
	
	quit()
