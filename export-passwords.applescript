set VOLNAME to "Passwords" -- Name of the encrypted disk image that will contain the exported keychain
set DISKDIR to path to documents folder from user domain as alias without folder creation
set DISKSIZE to 40 -- Disk image size in Megabytes

try
	set {keychainName, kechainPath} to chooseKeychain()
on error number -128 -- cancelled
	return
end try
-- Enable access for assistive devices (it may require a password)
try
	set oldStatusUI to setUIScripting(true, false)
on error errMsg
	criticalDialog("Could not enable UI Scripting: " & errMsg)
	return
end try

-- Create an encrypted disk image or attach it if it exists
set imagepath to (POSIX path of DISKDIR) & VOLNAME
try
	(POSIX file (imagepath & ".sparseimage")) as alias
	try
		do shell script "hdiutil attach " & imagepath & ".sparseimage -mount required"
	on error errMsg
		criticalDialog("Could not attach disk image: " & errMsg)
		setUIScripting(oldStatusUI, false)
		return
	end try
on error -- Disk image does not exist
	try
		do shell script "hdiutil create -quiet -size " & (DISKSIZE as text) & "m -fs HFS+J -encryption AES-256 -agentpass -volname " & VOLNAME & " -type SPARSE -attach " & imagepath
	on error errMsg
		criticalDialog("Could not create disk image: " & errMsg)
		setUIScripting(oldStatusUI, false)
		return
	end try
end try

-- Unlock keychain (it may prompt for the keychain password)
try
	do shell script "security -q unlock-keychain -u " & POSIX path of theKeychain
on error errMsg
	criticalDialog("Could not unlock the keychain: " & errMsg)
	setUIScripting(oldStatusUI, false)
	return
end try

-- Run security in the background and redirect output into the encrypted disk image
do shell script "security -q dump-keychain -d " & POSIX path of theKeychain & " &>/Volumes/" & VOLNAME & "/keychain-dump.txt &"
delay 3 -- Wait for SecurityAgent to start

-- Use access for assistive devices to automatically dispose of the dialogs
repeat
	try
		allowSecurityAccess()
		delay 0.5 -- Wait for the next SecurityAgent process
	on error
		exit repeat -- Assumes that security is over
	end try
end repeat

-- Revert the status of UI scripting (it may require a password)
try
	set oldStatusUI to setUIScripting(oldStatusUI, false)
on error errMsg
	criticalDialog("Could not revert the status of UI Scripting: " & errMsg)
	return
end try

-- [TODO]ÊPost-process security's output to produce a CSV-formatted file with this format (compatible with KeePass/1Password/theVault):

-- TODO: export the timestamp field and use it for synchronizing passwords (!)
display dialog "Finished!" buttons {"Great!"} default button 1
return

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

on allowSecurityAccess()
	tell application "System Events"
		tell process "SecurityAgent"
			click button "Allow" of group 1 of window 1
		end tell
	end tell
end allowSecurityAccess

on setUIScripting(newStatus, confirm)
	tell application "System Events" to set currentStatus to UI elements enabled
	if currentStatus is not newStatus then
		if confirm then
			set confirmed to confirmationDialog(exprif(currentStatus, "Disable", "Enable") & "UI Scripting now? (You may be asked to enter your password.)")
		else
			set confirmed to true
		end if
		if confirmed then tell application "System Events" to set UI elements enabled to newStatus
	end if
	return currentStatus
end setUIScripting

on confirmationDialog(message)
	tell me
		activate
		try
			display dialog message buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel" with icon note
		on error number -128
			return false
		end try
	end tell
	return true
end confirmationDialog

on criticalDialog(msg)
	display alert Â
		"A fatal error has occurred" message msg as critical Â
		buttons {"OK"} default button 1 Â
		giving up after 30
end criticalDialog

on exprif(condition, thenexpr, elseexpr)
	if condition then
		thenexpr
	else
		elseexpr
	end if
end exprif
