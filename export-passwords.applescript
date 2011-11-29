global VOLNAME, DISKDIR, DISKSIZE
set VOLNAME to "Passwords" -- Name of the encrypted disk image that will contain the exported keychain
set DISKDIR to path to documents folder from user domain as alias without folder creation
set DISKSIZE to 40 -- Disk image size in Megabytes

try
	exportKeychain()
on error errMsg number errNum
	if errNum is not -128 then criticalDialog(errMsg)
	return
end try

-- TODO: export the timestamp field and use it for synchronizing passwords (!)
display dialog "Finished!" buttons {"Great!"} default button 1
return

----------------------------------------------------------------------------
-- Auxiliary handlers
----------------------------------------------------------------------------

on exportKeychain()
	set {keychainName, keychainPath} to chooseKeychain()
	set keychainDump to "/Volumes/" & VOLNAME & "/" & keychainName & "-dump.txt"
	set keychainCSV to "/Volumes/" & VOLNAME & "/" & keychainName & ".csv"
	createAndAttachDiskImage(DISKDIR, VOLNAME, DISKSIZE)
	unlockKeychain(keychainPath)
	set rawData to dumpKeychainWithPasswords(keychainPath, keychainDump)
	set passwordItems to PasswordItemsFromKeychainDump(rawData)
	writeFile(keychainCSV, toCSV(passwordItems))
end exportKeychain

on importKeychain(csv)
	--set newPasswordItems to PasswordItemsFromCSV(csv)
	--set rawData to dumpKeychainWithoutPasswords(keychainPath, keychainDump)
	--set passwordItems to PasswordItemsFromKeychainDump(a reference to rawData)
	-- compare data structures and determines new/updated items
	-- prompt the use to select the items to import
	-- import selected items into the keychain
end importKeychain

-- Ask for the keychain to be exported
on chooseKeychain()
	set theKeychain to choose file with prompt Â
		"Please select the keychain to be exported:" of type {"com.apple.keychain"} Â
		default location (path to keychain folder from user domain) Â
		without invisibles, multiple selections allowed and showing package contents
	set {tid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, ":"}
	set theKeychainName to (characters 1 thru -10 of the last item of the text items of (theKeychain as text))
	set AppleScript's text item delimiters to tid
	{theKeychainName as text, theKeychain}
end chooseKeychain

on setUIScripting(newStatus)
	tell application "System Events"
		set {currentStatus, UI elements enabled} to {UI elements enabled, newStatus}
	end tell
	return currentStatus
end setUIScripting

on createAndAttachDiskImage(thePath, theName, theSize)
	set imagepath to (POSIX path of thePath) & theName & ".sparseimage"
	try -- to attach an existing disk image
		(POSIX file imagepath) as alias
		do shell script "hdiutil attach " & imagepath & " -mount required"
	on error number -1700 -- Disk image does not exist, create it
		do shell script "hdiutil create -quiet -size " & (theSize as text) & Â
			"m -fs HFS+J -encryption AES-256 -agentpass -volname " & theName & Â
			" -type SPARSE -attach " & imagepath
	end try
end createAndAttachDiskImage

on unlockKeychain(theKeychain)
	do shell script "security -q unlock-keychain -u " & POSIX path of theKeychain
end unlockKeychain

-- Returns a textual dump of the given keychain.
-- Works even when the keychain is locked. Never prompts for passwords.
on dumpKeychainWithoutPasswords(theKeychain)
	do shell script "security -q dump-keychain " & POSIX path of theKeychain
end dumpKeychainWithoutPasswords

-- Returns a textual dump of the given keychain, including sensitive data.
-- The keychain should be unlocked.
-- The dump is written to a file, so dumpPath should point to an encrypted disk image for improved security.
on dumpKeychainWithPasswords(theKeychain, dumpPath)
	set oldStatusUI to setUIScripting(true)
	
	-- Run security in the background and redirect the output to a file
	do shell script "security -q dump-keychain -d " & POSIX path of theKeychain & " &>" & dumpPath & " &"
	delay 3 -- Wait for SecurityAgent to start
	
	-- Use access for assistive devices to automatically dispose of SecurityAgent's dialogs
	repeat
		try
			allowSecurityAccess()
			delay 0.5 -- Wait for the next SecurityAgent process
		on error
			exit repeat -- Assumes that security is over
		end try
	end repeat
	
	setUIScripting(oldStatusUI)
	read (POSIX file dumpPath as alias) from 1 to eof as text
end dumpKeychainWithPasswords

on allowSecurityAccess()
	tell application "System Events"
		tell process "SecurityAgent"
			click button "Allow" of group 1 of window 1
		end tell
	end tell
end allowSecurityAccess

on writeFile(thePosixPath, theData)
	set fd to open for access POSIX file thePosixPath with write permission
	try
		write theData to fd as text
	on error errMsg number errNum
		close access fd -- Ensure that the file descriptor is released
		error errMsg number errNum
	end try
	close access fd
end writeFile

on criticalDialog(msg)
	display alert Â
		"A fatal error has occurred" message "This script will be terminated because the following error has occurred: " & return & return & msg as critical Â
		buttons {"OK"} default button 1 Â
		giving up after 30
end criticalDialog

on PasswordItemsFromCSV(source)
	script Parser
		property passwordItems : {}
		return passwordItems
	end script
	run Parser
end PasswordItemsFromCSV

on PasswordItemsFromKeychainDump(source)
	script Parser
		property passwordItems : {{"Label", "Account", "Password"}} -- Header
		
		set keychainItems to split(source, "keychain: ")
		repeat with ki in keychainItems
			if ki contains "class: \"genp\"" then
				set rec to the rest of split(ki, "attributes:") as text
				set label to extract(rec, "0x00000007")
				set account to extract(rec, "acct")
				set thePassword to extract(rec, "data")
				set the end of passwordItems to {label, account, thePassword}
			end if
		end repeat
		return my passwordItems
		
		on extract(theRecord, field)
			set LF to string id 10
			set SP to string id 32
			set type to fieldtype(field)
			if field is "data" then
				set theKey to "data:" & LF
			else if field starts with "0x" then
				set theKey to field & " <" & type & ">=" -- E.g., 0x00000007 <blob>=
			else
				set theKey to quote & field & quote & "<" & type & ">=" -- E.g., "acct"<blob>=
			end if
			set theValue to textBetween(theRecord, theKey, LF) as text
			if theValue starts with "0x" then
				decode(the first item of split(theValue, {SP, LF}), type)
			else
				cleanup(theValue)
			end if
		end extract
		
		on fieldtype(field)
			if field starts with "0x" or field is in {"acct", "atyp", "data", "desc", "gena", "icmt", "path", "prot", "sdmn", "srvr", "svce"} then
				"blob"
			else if field in {"cdat", "mdat"} then
				"timedate"
			else if field in {"crtr", "ptcl", "type"} then
				"uint32"
			else if field in {"cusi", "invi", "nega", "scrp"} then
				"sint32"
			else
				missing value
			end if
		end fieldtype
		
		on cleanup(x)
			exprif(x is "<NULL>", "", unquote(x))
		end cleanup
		
		-- Decodes a hexadecimal string (e.g., "0x1BC" returns "444").
		-- The type field is used to determine whether the hexadecimal value
		-- must be interpreted as a UTF8 string or as an integer.
		-- The type of the return value is text in any case.
		on decode(x, type)
			set hexdata to text 3 thru -1 of x -- Get rid of "0x"
			if type is in {"blob", "timedate"} then
				hexToUTF8(hexdata)
			else if type starts with "uint" then
				hexToDec(hexdata)
			else
				error "Cannot decode the given data type: " & type
			end if
		end decode
	end script
	run Parser
end PasswordItemsFromKeychainDump

-- Interprets a hexadecimal string as UTF8-encoded text
on hexToUTF8(hexstring)
	run script "Çdata utf8" & hexstring & "È as text"
end hexToUTF8

-- Converts a hexadecimal string to an integer value
on hexToDec(hexstring)
	run script "Çdata long" & reversebytes(hexstring) & "È as text"
end hexToDec

on reversebytes(x)
	set {i, s} to {(count x) - 1, ""}
	repeat
		if i < 1 then exit repeat
		set s to s & text i thru (i + 1) of x
		set i to i - 2
	end repeat
	s
end reversebytes

on unquote(x)
	set {l, r} to {1, -1}
	if x starts with quote then set l to 2
	if x ends with quote then set r to -2
	try
		text l thru r of x
	on error
		x
	end try
end unquote

on exprif(cond, _then, _else)
	if cond then
		_then
	else
		_else
	end if
end exprif

on split(theText, theDelim)
	set {tid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, theDelim}
	set theResult to the text items of theText
	set AppleScript's text item delimiters to tid
	return theResult
end split

-- Returns the list of occurrences in the given text
-- which are enclosed by the given (distinct) delimiters
on textBetween(theText, leftDelim, rightDelim)
	set t to the rest of split(theText, leftDelim)
	set theResult to {}
	repeat with rec in t
		set s to split(rec, rightDelim)
		if length of s > 1 then set the end of theResult to the first item of s
	end repeat
	theResult
end textBetween

-- Returns a CSV text from a list of (homogeneous) lists.
on toCSV(listOfLists)
	set {tid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, quote & ";" & quote}
	set csv to ""
	repeat with rec in listOfLists
		set csv to csv & quote & (rec as text) & quote & return
	end repeat
	set AppleScript's text item delimiters to tid
	csv
end toCSV
