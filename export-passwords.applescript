set VOLNAME to "Passwords" -- Name of the encrypted disk image that will contain the exported keychain
set DISKDIR to path to documents folder from user domain as alias without folder creation
set DISKSIZE to 40 -- Disk image size in Megabytes

try -- to choose keychain
	set {keychainName, keychainPath} to chooseKeychain()
on error number -128 -- cancelled
	return
end try

try -- to dump keychain data into an encrypted disk image
	createAndAttachDiskImage(DISKDIR, VOLNAME, DISKSIZE)
	unlockKeychain(keychainPath)
	dumpKeychain(keychainPath, Â
		"/Volumes/" & VOLNAME & "/" & keychainName & "-dump.txt")
on error errMsg
	criticalDialog(errMsg)
	return
end try

-- [TODO]ÊPost-process security's output to produce a CSV-formatted file with this format (compatible with KeePass/1Password/theVault):

-- TODO: export the timestamp field and use it for synchronizing passwords (!)
display dialog "Finished!" buttons {"Great!"} default button 1
return


----------------------------------------------------------------------------
-- Auxiliary handlers
----------------------------------------------------------------------------

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

on dumpKeychain(theKeychain, theOutPathname)
	set oldStatusUI to setUIScripting(true)
	
	-- Run security in the background and redirect the output to a file
	do shell script "security -q dump-keychain -d " & POSIX path of theKeychain & " &>" & theOutPathname & " &"
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
end dumpKeychain

on allowSecurityAccess()
	tell application "System Events"
		tell process "SecurityAgent"
			click button "Allow" of group 1 of window 1
		end tell
	end tell
end allowSecurityAccess

on criticalDialog(msg)
	display alert Â
		"A fatal error has occurred" message "This script will be terminated because the following error has occurred: " & return & return & msg as critical Â
		buttons {"OK"} default button 1 Â
		giving up after 30
end criticalDialog
