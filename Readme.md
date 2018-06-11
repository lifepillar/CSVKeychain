# CSVKeychain AppleScript script

This repo contains scripts to export all your password items and secure notes
from Apple's Keychain.app into plain text files in CSV format, merge such files
and import them back into a keychain.

No trick or reverse engineering is used: exporting is performed by Apple's
`security` tool, using macOS's assistive support to streamline the process.

The current master should work in (High) Sierra.
Earlier versions of macOS/OS X are not supported.


## How to use

To import/export password items, open the AppleScript script in Script Editor.
The script may be run from source.

Before running the script, go to System Preferences > Security & Privacy >
Privacy > Accessibility, and allow Script Editor to control your computer.
This step is
required to avoid SecurityAgent to prompt you with a dialog for each item you
want to export. It basically allows AppleScript to press the Allow button in
such dialogs for you.

You may also build the script into an application if you want. In this case, you
must grant the app control of your computer in the same way.

The script always asks for the password to unlock your keychain (you recognise
the dialog by the Script Editor icon). Since that dialog is not very
secure, it is recommended that you change your keychain's password in
Keychain.app before exporting your keychain, and restore the original password
afterwards. You may also be asked to unlock your keychain by SecurityAgent
(which you do by providing your keychain's password). So, you may have to enter
your keychain's password once or twice. After that, SecurityAgent will keep
prompting for a password for each exported item, but the script should fill it
out for you automatically, so no further action from you will be required.

The script makes a backup of the keychain before importing or exporting data.
Backups are timestamped and saved into the same folder containing the keychain.
In any case, it is a good idea to keep a separate backup, just in case.

When importing items into a keychain, *matching items already present in the
keychain are overwritten if their timestamps are older than the timestamps of
the items being imported.* If there are items without timestamps in the CSV
file, the script will ask the user what to do with them. Note that this will be
asked once and the choice applied to all the items being imported.

Also note that *all* new or updated items are assigned the current time as their
new timestamps. There is no possibility to retain the original timestamps from
the CSV file.

Finally, access control lists are not exported.


## Troubleshooting

If you get this error:

```
This script will be terminated prematurely because the following error has
occurred:

security: SecKeychainUnlock [...]: The user name or
passphrase you entered is not correct. (Error number: 51)
```

open Keychain.app and lock your keychain. Then, run the script again.

## Merging files

A Ruby script is provided to merge two CSV files containing password data into
one. See `./merge_csv.rb --help` for the details.


## Is it possible to export the Local Items (aka iCloud) keychain?

Not directly. The Local Items keychain, located at
`~/Library/Keychain/<UUID>/<name>.db`, is a SQLite database containing
obfuscated data, so its format is different from the format of a standard
keychain. As far as I can see, `security` cannot dump such keychains, and I do
not know of any tool that would do that.

You may proceed as follows:

1. In Keychain.app, create a new keychain: File > New Keychain…
2. Select the Local Items keychain in the sidebar, then select all the items
   (or the ones you want to export) and copy them by choosing Edit > Copy.
3. Select the keychain created at step one and choose Edit > Paste.

Such process is painful, though, because Keychain.app will keep asking for
a password for each item. You may automate such process with [a bit of
scripting](https://gist.github.com/rmondello/b933231b1fcc83a7db0b). For your
convenience, the script that allows you to fill in the password prompts for you
is reported below:

```applescript
tell application "System Events"
	repeat while exists (processes where name is "SecurityAgent")
		tell process "SecurityAgent"
			set frontmost to true
			try
				keystroke "PUT YOUR KEYCHAIN'S PASSWORD HERE"
				delay 0.1
				keystroke return
				delay 0.1
			on error
				-- do nothing to skip the error
			end try
		end tell
		delay 0.5
	end repeat
end tell
```

You may run this directly from Script Editor. A similar approach can be used to
export `/Library/Keychains/System.keychain`.

**Note:** Keychain.app won't allow you to paste some items (most likely,
automatically created by the system, not yours). In such case, the snippet above
will produce a script error and Keychain.app will show an error dialog, too.
Dismiss both and run the script again. Repeat every time you get an error.


## Migrate passwords and notes into KeePass

If you want to import the CSV file generated by CSVKeychain into a KeePass
2 database and you are on macOS, you may need to convert it to XML first. For
such purpose, add a category column to the CSV file using the included
`add_category.rb` script. Then, use my
[csv2keepassxml](https://github.com/lifepillar/csv2keepassxml) to generate
a KeePass 2 XML file.


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
