set VOLNAME to "Passwords" -- Name of the disk image

-- [TODO]: ask for the keychain to be exported

-- Enable access for assistive devices (it may require a password)
try
	set oldStatusUI to setUIScripting(true, false)
on error errMsg
	display dialog "Could not enable UI Scripting: " & errMsg
	return
end try

-- Create an encrypted disk image
set imagepath to (POSIX path of (path to downloads folder)) & VOLNAME
try
	do shell script "hdiutil create -quiet -size 40m -fs HFS+J -encryption AES-256 -agentpass -volname " & VOLNAME & " -type SPARSE -attach " & imagepath
on error errMsg
	display dialog "Could not create disk image: " & errMsg
	setUIScripting(oldStatusUI, false)
	return
end try

-- Unlock keychain
try
	do shell script "security -q unlock-keychain -u /Users/nicola/Library/Keychains/test.keychain"
on error errMsg
	display dialog errMsg
	return
end try

-- Run security in the background and redirect output into the encrypted disk image
do shell script "security -q dump-keychain -d /Users/nicola/Library/Keychains/test.keychain &>/Volumes/" & VOLNAME & "/passwords.txt &"
delay 5 -- Wait for SecurityAgent to start

-- Use access for assistive devices to automatically dispose of the dialogs
repeat
	try
		allowSecurityAccess()
		delay 1 -- Wait for the next SecurityAgent process
	on error
		exit repeat -- Assumes that security is over
	end try
end repeat

-- Revert the status of UI scripting (it may require a password)
try
	set oldStatusUI to setUIScripting(oldStatusUI, false)
on error errMsg
	display dialog "Could not enable UI Scripting: " & errMsg
	return
end try

-- [TODO]ÊPost-process security's output to produce a CSV-formatted file with this format (compatible with KeePass/1Password/theVault):

-- TODO: export the timestamp field and use it for synchronizing passwords (!)
display dialog "Finished!" buttons {"Great!"} default button 1

on allowSecurityAccess()
	tell application "System Events"
		tell process "SecurityAgent"
			--set theElements to UI elements of group 1 of window 1
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

on exprif(condition, thenexpr, elseexpr)
	if condition then
		thenexpr
	else
		elseexpr
	end if
end exprif
