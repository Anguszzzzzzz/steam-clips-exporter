#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage:
  --watch-path <path>: the directory where steam keeps clips, usually it's <your steam recording directory>/clips
  --output-path <path>: the directory where you want to output your video files, if not specified, it will output to an output directory under the same directory as the script
  --output-directory <true|false>: whether a new subdirectory should be created with the game's name, enabled by default
  Or set environment variables: WATCH_PATH, OUTPUT_PATH, OUTPUT_DIRECTORY"
  exit 1
}

# Check dependencies
for cmd in curl jq ffmpeg; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd is required."; exit 1; }
done

# Defaults from environment, can be overridden by CLI
WATCH_PATH="${WATCH_PATH:-}"
OUTPUT_PATH="${OUTPUT_PATH:-}"
OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY:-true}"

# Parse CLI arguments (override env if present)
while [[ "$#" -gt 0 ]]; do
  case $1 in
    "--watch-path") WATCH_PATH="$2"; shift ;;
    "--output-path") OUTPUT_PATH="$2"; shift ;;
    "--output-directory") OUTPUT_DIRECTORY="$2"; shift ;;
    "--help"|"-h") usage ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

if [[ -z "$WATCH_PATH" ]]; then
  echo "Error: Watch path is required"
  usage
fi

output_path="${OUTPUT_PATH:-"$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/output"}"
output_directory="$OUTPUT_DIRECTORY"

# Keep track of processed folders
data_path="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/data"
mkdir -p "$data_path"
PROCESSED_FILE="$data_path/processed_clips.txt"
touch "$PROCESSED_FILE"

process_clip_folder() {
  input_path="$1"
  input=$(basename "$input_path")
  if [[ $input =~ ^clip_([0-9]+)_([0-9]{8})_([0-9]{6})$ ]]; then
    steam_app_id="${BASH_REMATCH[1]}"
    date_part="${BASH_REMATCH[2]}"
    time_part="${BASH_REMATCH[3]}"
  else
    echo "Error: Could not extract timestamp or steam_app_id from input: $input"
    return 1
  fi

  utc_datetime="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}T${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
  formatted_time=$(TZ="America/Los_Angeles" date -d "$utc_datetime UTC" +"%Y-%m-%d %H-%M-%S")

  url="https://store.steampowered.com/api/appdetails?appids=$steam_app_id"
  response=$(curl -s "$url")
  title=$(echo "$response" | jq -r ".[\"$steam_app_id\"].data.name // empty" | tr -d '[:punct:]')
  if [[ -z "$title" ]]; then
    echo "Error: Could not retrieve game title for App ID $steam_app_id, using steam app id as title"
    title="$steam_app_id"
  fi

  output_filename="${title} ${formatted_time}.mp4"
  local out_path="$output_path"
  if [[ "$output_directory" == "true" ]]; then
    out_path="${out_path%%/}/${title}"
  fi
  echo "Output path: $out_path"
  echo "Output filename: $output_filename"

  tmp_video_file=$(mktemp /var/tmp/steamclip_video_XXXXXX)
  tmp_audio_file=$(mktemp /var/tmp/steamclip_audio_XXXXXX)

  # A trap to clean up temp files on any exit from this function
  cleanup() {
    rm -f "$tmp_video_file" "$tmp_audio_file"
  }
  trap cleanup EXIT
  
  video_dir="$(find "$input_path/video" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "$video_dir" ]]; then
    echo "Error: No video directory found in $input_path/video"
    rm -f "$tmp_video_file" "$tmp_audio_file"
    return 1
  fi

  video_chunks=$(ls "$video_dir" | grep -i "chunk-stream0" | xargs)
  audio_chunks=$(ls "$video_dir" | grep -i "chunk-stream1" | xargs)

  cd "$video_dir"
  cat "init-stream0.m4s" > "$tmp_video_file"
  for chunk in $video_chunks; do cat "$chunk" >> "$tmp_video_file"; done
  cat "init-stream1.m4s" > "$tmp_audio_file"
  for chunk in $audio_chunks; do cat "$chunk" >> "$tmp_audio_file"; done

  # Check if output file already exists
  if [[ -f "$out_path/$output_filename" ]]; then
    echo "Output file already exists: $out_path/$output_filename"
    return 0
  fi

  mkdir -p "$out_path"
  cd "$out_path"
  ffmpeg -loglevel error -i "$tmp_video_file" -i "$tmp_audio_file" -n -c copy "$output_filename"

  echo "Clip processed and output to: $out_path/$output_filename"
  rm -f "$tmp_video_file" "$tmp_audio_file"
}

echo "Polling $WATCH_PATH for new clip folders..."
while true; do
  mapfile -d '' new_dirs < <(find "$WATCH_PATH" -maxdepth 1 -type d -name 'clip_*' -print0)
  for dir in "${new_dirs[@]}"; do
    if [[ -d "$dir" ]] && ! grep -Fxq "$dir" "$PROCESSED_FILE"; then
      echo "Detected new clip folder: $dir"
      echo "Waiting for the folder to be fully written"
      sleep 30
      process_clip_folder "$dir"
      echo "$dir" >> "$PROCESSED_FILE"
      echo "Resuming monitoring"
    fi
  done
  sleep 10
done