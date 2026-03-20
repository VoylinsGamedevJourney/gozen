from PIL import Image, ImageDraw, ImageFont
import os

width, height = 100, 100
font = ImageFont.load_default()


for i in range(1, 301):
    img = Image.new("RGB", (width, height), color="white")
    draw = ImageDraw.Draw(img)

    text = str(i)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (width - text_width) // 2
    y = (height - text_height) // 2

    draw.text((x, y), text, fill="black", font=font)
    file_path = f"{i:03}.webp"
    img.save(file_path, "WEBP", quality = 20, method = 6)

print("Done! 300 images generated.")
