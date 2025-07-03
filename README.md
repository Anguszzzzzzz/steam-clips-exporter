# Steam Clips Exporter

[![GitHub Repository](https://img.shields.io/badge/GitHub-Repository-orange.svg)](https://github.com/anguszzzzzzz/steam-clips-exporter)
[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.txt)

A Bash script that monitors new and existing Steam Game Recording Clips, and automatically exports clips into individual MP4 files.

## Description

This script runs continuously to watch the specified Steam Game Recording Clips directory for any new clips, extracts the new clip's game title and timestamp, retrieves the game title using the Steam API, and then uses FFmpeg to process the clip into a single MP4 file. The output file is placed in the specified output directory.

#### Important Notes

* Make sure that the user you're running the script with has proper access to the watch path and output directory.
* The script checks for existing clip files in the output path. If the clip to be generated already exists in the output path, the existing file will NOT be overwritten.
* The script uses a data file in the "data" directory alongside the script to keep track of processed clips. If you want to clear this list and start over, delete the `processed_clips.txt` file.
* Output files are named with the game title followed by the timestamp of the clip. For example: `<game-title> 2023-10-07 14-56-38.mp4`.

## Requirements

* `curl`
* `jq`
* `FFmpeg`
* Internet connection

## Usage

You can run this script from the command line by making it executable (`chmod +x steam-clips-exporter.sh`) and then running `steam-clips-exporter.sh` using either command line options, or environment variables such as when running as a systemd service.

| Command Line Option       | Environment Variable | Description                                                                                         | Example Value | Required |
| ------------- | -------------------- | --------------------------------------------------------------------------------------------------- | --- | --- |
| --watch-path  | WATCH_PATH           | The directory where Steam keeps clips, usually it's `/<your-steam-recording-directory>/clips`      | `/<your-steam-recording-directory>/clips`    | Required     |
| --output-path | OUTPUT_PATH          | The directory where you want to output your video files. If not specified, it will output to an "output" directory under the same directory as the script.                                          | `/<your-output-directory>`         | Optional   |
| --output-directory            | OUTPUT_DIRECTORY      | Whether a new subdirectory should be created with the game's title, enabled by default.           | `true` or `false`          | Optional       |

You can test this script by running `./steam-clips-exporter.sh --watch-path "/path-to-testing-clips"` on a testing directory that contains at least one steam clip.

## Running as a systemd Service

To run this script as a systemd service, follow these steps:

1. Create a new file in `/etc/systemd/system/` called `steam-clips-exporter.service`. Add the following contents in your favourite text editor:
```bash
[Unit]
Description=Steam Clips Exporter
After=network.target

[Service]
Type=simple
Environment="WATCH_PATH=/<your-steam-recording-directory>/clips"
Environment="OUTPUT_PATH=/<your-output-directory>"
ExecStart=/usr/bin/bash /<path-to-your-script-location>/steam-clips-exporter.sh
Restart=on-failure
User=<your-username>
WorkingDirectory=/<path-to-your-script-location>

[Install]
WantedBy=multi-user.target
```

2. Replace: `<your-steam-recording-directory>`, `<your-output-directory>`, and `<path-to-your-script-location>` with the appropriate paths on your system.
Replace `<your-username>` with the username of the user who will be running this script.
Save the file and exit the editor.

3. Reload systemd daemon to pick up changes: `sudo systemctl daemon-reload`

4. Start the service: `sudo systemctl start steam-clips-exporter.service`

5. Check the status of your service and confirm that it is running successfully: `sudo systemctl status steam-clips-exporter.service`, or view the logs of your service: `sudo journalctl -u steam-clips-exporter.service`

6. If everything works as expected, enable your service to start automatically on boot: `sudo systemctl enable steam-clips-exporter.service`

## Contributing

If you'd like to contribute to this project, please fork it and submit a pull request.

## License

This project is licensed under the MIT License. See LICENSE.txt for details.