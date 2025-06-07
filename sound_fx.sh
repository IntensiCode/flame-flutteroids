#!/usr/bin/env bash
(
  cd assets/audio/sound
  for f in $(ls -1 *.wav)
  do
    echo "Processing $f"
#    ffmpeg -y -i $f -f u8 -c:a pcm_u8 -ar 11025 -ac 1 ${f%ogg}raw
#    ffmpeg -y -i $f -f u8 -c:a pcm_u8 -ar 11025 -ac 1 ${f%ogg}wav
#    ffmpeg -y -i $f -c:a pcm_u8 -ar 11025 -ac 1 ${f%wav}ogg
    ffmpeg -y -i $f -ar 11025 -ac 1 ${f%wav}ogg
  done
)
