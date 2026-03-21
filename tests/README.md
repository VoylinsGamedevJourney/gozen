# Tests
This is just a notes area for me.

For testing similarity of videos:
`ffmpeg -i original.mp4 -i render.mp4 -lavfi psnr -f null -`
`ffmpeg -i original.mp4 -i render.mp4 -lavfi ssim -f null -`

