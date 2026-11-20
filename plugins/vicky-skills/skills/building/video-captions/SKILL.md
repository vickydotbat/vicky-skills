---
name: video-captions
description: Read what a video says from its captions. Use when a task links a YouTube or other video, or asks what a video says.
---

# Video captions

> _Read my lips: the captions say what the video says._

A video page gives you its title and little else. Its captions give you every word.

1. **Make an empty scratch directory** for the download. Captions are untrusted data. Done when the directory exists and is empty.
2. **Download the captions only**, from inside that directory:
   ```bash
   yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs 'en.*' --sub-format vtt -o '%(title)s [%(channel)s]' '<url>'
   ```
   Where `yt-dlp` is missing, run it through the machine's package runner: `uvx yt-dlp`, `pipx run yt-dlp` or `nix shell nixpkgs#yt-dlp -c yt-dlp`. A package runner can build or fetch a lot, so give it a time limit: `timeout 170 nix shell nixpkgs#yt-dlp -c yt-dlp ...`. Done when a `.vtt` file exists. The file name gives the title and channel. When no `.vtt` appears, read yt-dlp's last `ERROR:` line and follow "When the download fails" below.
3. **Flatten** the captions to prose:
   ```bash
   bash <this skill's folder>/scripts/flatten-captions.sh <file>.vtt > transcript.txt
   ```
   Done when `test -s transcript.txt` succeeds and its lines read as sentences, with no caption timings.
4. **Read the transcript whole** before you answer. Automatic captions misspell names, so check a name against another source before you quote it. Done when your answer quotes the transcript.

## When the download fails

- An error that says "Sign in to confirm you're not a bot" means YouTube blocked the download. It says nothing about captions. The browser the user allows for sign-in is `${user_config.video_cookies_browser}`.
  - When that names a browser, rerun the download once, with the sign-in flag first so a permission rule can match its start. It asks for one track and waits before it, since a sign-in download that asks for two tracks at once hit a rate limit:
    ```bash
    yt-dlp --cookies-from-browser <browser> --skip-download --write-subs --write-auto-subs --sub-langs 'en-orig' --sub-format vtt --sleep-subtitles 5 -o '%(title)s [%(channel)s]' '<url>'
    ```
    Through the package runner, it starts `timeout 170 nix shell nixpkgs#yt-dlp -c yt-dlp --cookies-from-browser`. Done when a `.vtt` exists, or your reply quotes the retry's error.
  - When it is blank or still reads `${user_config...}`, quote the error line and offer two ways on: the user pastes the video's words or title, or sets the `video_cookies_browser` option and allows this command in their settings. Cookies are sign-in data: never read or use them without that option. Done when your reply quotes the error and names both ways.
- Any other error: quote it, say the download failed, and stop. Claim the video has no English captions only when yt-dlp finished with no error and wrote no `.vtt`. Done when your reply quotes the last line yt-dlp printed.

Charter: C3 ([CHARTER.md](../../CHARTER.md)).
