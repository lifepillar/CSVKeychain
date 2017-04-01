# CSVKeychain AppleScript script

This script allows you to export all your password items and secure notes from
Apple's Keychain.app into a plain text file in CSV format, and it allows you to
import CSV files back into a keychain.

The script does not use any trick or reverse engineering: it just uses Apple's
`security` tool and takes advantage of macOS's assistive support.

Tested in macOS Sierra. Earlier versions of macOS/OS X are not supported.


## How to use

You may run the script from source. Just open it in Script Editor.

Before running the script, go to System Preferences > Security & Privacy >
Accessibility, and allow Script Editor to control your computer. This step is
required to avoid SecurityAgent to prompt you with a dialog for each item you
want to export. It basically allows AppleScript to press the Allow button in
such dialogs for you.

You may also build the script into an application if you want. In this case, you
must grant the app control of your computer in the same way.

The script makes a backup of your keychain before importing or exporting data.
Backups are timestamped and saved into the same folder containing the keychain.
In any case, it is a good idea to keep a separate backup, just in case.

When importing items into a keychain, matching items in the keychain are
overwritten if their timestamps are older than the timestamps of the item being
imported. If a keychain's item has no timestamp, then the item is duplicated. If
there are items without timestamps in the CSV file, the script asks the user
what to do.


## License

Copyright (c) 2011–2017, Lifepillar

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
