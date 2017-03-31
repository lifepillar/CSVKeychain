(*!
	@header
		Keychain CSV Import/Export
	@abstract
		Export/import Keychain.app's keychains to/from CSV format.
	@discussion
		The following table shows the correspondence between some of the codes and terminology
		used by the <tt>security</tt> tool in OS X Lion and the corresponding terminology
		in Keychain Access, when available.

		<table border="1">
		<tr><th>Code</th><th>security</th><th>Keychain Access</th></tr>
		<tr><td>0x00000007</td><td>label</td><td>Name</td></tr>
		<tr><td>"acct"</td><td>account</td><td>Account</td></tr>
		<tr><td>"cdat"</td><td>(creation timestamp)</td><td>NA</td></tr>
		<tr><td>"crtr"</td><td>creator</td><td>NA</td></tr>
		<tr><td>"desc"</td><td>kind</td><td>Kind (e.g., <tt>"application password"</tt>)</td></tr>
		<tr><td>"icmt"</td><td>comment string</td><td>Comments</td></tr>
		<tr><td>"mdat"</td><td>(modification timestamp)</td><td>Date Modified</td></tr>
		<tr><td>"svce"</td><td>service</td><td>Where</td></tr>
		<tr><td>"type"</td><td>Type</td><td>NA (1)</td></tr>
		<tr><td>"atyp"</td><td>authentication type</td><td>NA</td></tr>
		<tr><td>"path"</td><td>path</td><td>Where (2)</td></tr>
		<tr><td>"port"</td><td>port</td><td>Where (2)</td></tr>
		<tr><td>"ptcl"</td><td>protocol</td><td>Where (2)(3)</td></tr>
		<tr><td>"sdmn"</td><td>security domain</td><td>NA</td></tr>
		<tr><td>"srvr"</td><td>server name</td><td>Where (2)</td></tr>
		</table>

		Notes:

		<dl>
			<dt>(1)</dt><dd>In Keychain Access, the type is not explicitly available.
				Generic passwords whose type is <tt>note</tt>, however, are displayed as secure notes.</dd>
			<dt>(2)</dt><dd>For internet passwords, the <em>Where</em> field in Keychain Access
				contains the compound value <tt>protocol://server/path:port</tt>.</dd>
			<dt>(3)</dt><dd>The four-letter protocol codes are:</dd>
		</dl>
		<pre>
		"ftp ", "ftpa", "http", "irc ", "nntp", "pop3", "smtp", "sox ", "imap", "ldap",
		"atlk", "afp ", "teln", "ssh ", "ftps", "htps", "htpx", "htsx", "ftpx", "cifs", "smb ",
		"rtsp", "rtsx", "daap", "eppc", "ipp ", "ntps", "ldps", "tels", "imps", "ircs", "pops",
		"cvsp", "svn ".
		</pre>

		In this script, we use <tt>security</tt>'s terminology, with only one exception: the variable
		<tt>|where|</tt> is used to refer to a value that can be either the service (for generic passwords) 
		or the compound value <tt>protocol://server/path:port</tt> (for internet passwords), that is, what
		in Keychain Access is the <em>Where</em> field.

	@version 2.0.0
	@copyright 2011Ð2017 Lifepillar
*)


(*! The names of a password item's fields. *)
property FIELDS : ({"Where", "Account", "Password", "Label", "Comment", "Created", "Modified", "Kind", "Type", "Domain", "AuthType", "Class", "Creator"})

(*! @abstract Flag to enable or disable exporting of secure notes. *)
property EXPORT_SECURE_NOTES : true

(*! Feasible values are <tt>"Allow"</tt> and <tt>"Always allow"</tt>. *)
property ALLOW_SECURITY : "Allow"

property LF : linefeed
property CR : return
property SP : space
property ERR_NOT_PASSWORD_ITEM : 9999

global PasswordItem


----------
-- Main --
----------

try
	
	activate
	display dialog Â
		"Please choose if you want to export a keychain into a CSV file or you want to import data from a CSV file into a keychain." buttons {"Cancel", "Export", "Import"} Â
		default button "Export" cancel button "Cancel" with title "Export or Import Data?" with icon note
	set action to the button returned in the result
	
on error number -128
	return
end try

try
	
	if action is "Import" then
		importCSV()
	else if action is "Export" then
		exportKeychain()
	else
		error "This task cannot be performed: " & action
	end if
	
on error errMsg number errNum
	
	if errMsg's length is greater than 480 then set errMsg to text 1 thru 480 of errMsg
	if errNum is not -128 then criticalDialog((errMsg & return & "(Error number: " & errNum as text) & ")")
	return
	
end try

set info to action & " operation completed successfully!"

if action is "Import" then
	set info to info & return & return & "It is recommended that you verify your keychain by choosing Keychain Access > Keychain First Aid."
end if

activate
display dialog info buttons {"Quit"} default button 1 with title "Success!" with icon note

return -- THE END


----------------------------------------------------------------------------
-- Auxiliary handlers
----------------------------------------------------------------------------

(*!
	@abstract
		Exports the content of a keychain file (passwords and secure notes)
		into a plain CSV file.
	@return
		Nothing.
	@throws
		ÒUser canceledÓ error if the user interrupts the process.
*)
on exportKeychain()
	
	set {keychainName, keychainPath} to Â
		chooseFile("Please select the keychain file to be exported:", "com.apple.keychain", path to keychain folder from user domain)
	
	display dialog Â
		"Do you want to also export secure notes?" buttons {"Yes", "No", "Cancel"} Â
		default button "Yes" cancel button "Cancel" with title "Export secure notes?" with icon note
	if button returned in the result is "No" then
		set EXPORT_SECURE_NOTES to false
	end if
	
	set outputDirectory to choose folder with prompt Â
		"Where do you want to save the result?" default location (path to downloads folder from user domain) Â
		without invisibles, multiple selections allowed and showing package contents
	
	set keychainDump to (POSIX path of outputDirectory) & "/" & keychainName & "-dump.txt"
	askIfFileExists(keychainDump)
	set keychainCSV to (POSIX path of outputDirectory) & "/" & keychainName & ".csv"
	askIfFileExists(keychainCSV)
	
	do shell script Â
		"ditto " & quoted form of POSIX path of keychainPath & " " & quoted form of (POSIX path of keychainPath & "-" & timestamp() & ".backup")
	
	unlockKeychain(keychainPath)
	
	set keychainData to dumpKeychainWithPasswords(keychainPath, keychainDump, ALLOW_SECURITY)
	set passwordItems to PasswordItemsFromKeychainDump(keychainData)
	
	writeUTF8File(keychainCSV, toCSV(passwordItems))
	
end exportKeychain


(*!
	@abstract
		Imports password items and secure notes from a plain CSV file.
	@discussion
		TODO
	@return
		Nothing.
	@throws
		ÒUser cancelledÓ error if the user interrupts the process.
*)
on importCSV()
	
	set {keychainName, keychainPath} to Â
		chooseFile("Please select the keychain to import items into:", "com.apple.keychain", path to keychain folder from user domain)
	
	set {csvName, csvPath} to Â
		chooseFile("Please select the CSV file to be imported:", "public.comma-separated-values-text", path to home folder from user domain)
	
	do shell script Â
		"ditto " & quoted form of POSIX path of keychainPath & " " & quoted form of (POSIX path of keychainPath & "-" & timestamp() & ".backup")
	
	set csvData to readUTF8File(csvPath)
	
	set csvPasswordItems to PasswordItemsFromCSV(csvData, CSV_SEPARATOR)
	
	unlockKeychain(keychainPath)
	
	toKeychain(keychainPath, csvPasswordItems)
	
end importCSV


(*!
	@abstract
		Returns a CSV-formatted text from a list of (homogeneous) lists.
	@discussion
		TODO
	@param
		listOfLists <em>[list]</em> A list of lists.
	@return
		a CSV-formatted text.
	@throws
		Nothing.
*)
on toCSV(listOfLists)
	
	script CSVWriter
		
		property lol : listOfLists
		
		set {tid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, quote & "," & quote}
		set csv to ""
		
		repeat with rec in (a reference to lol)
			repeat with i from 1 to count rec
				-- Escape quotes
				set item i of rec to replace(item i of rec, quote, quote & quote)
			end repeat
			set csv to csv & quote & (rec as text) & quote & LF
		end repeat
		
		set AppleScript's text item delimiters to tid
		
		return csv
		
	end script
	
	run CSVWriter
	
end toCSV


(*!
	@abstract
		Imports a CSV-formatted list of password items and secure notes into a keychain.
	@discussion
		TODO
	@param
		keychain (<em>alias</em> | <em>file</em> | <em>text</em>) The absolute path to a keychain file.
	@param
		csvPasswordItems <em>[text]</em> CSV-formatted text.
	@return
		Nothing.
*)
on toKeychain(keychain, csvPasswordItems)
	
	script KeychainImporter
		
		property pItems : csvPasswordItems
		
		set override to false
		
		-- Check whether there are items without a timestamp. If so, ask the user what to do with them.
		repeat with rec in (a reference to pItems)
			
			if rec's |modified| is "" then
				activate
				display dialog Â
					"Among the items to be imported, some do not have the Òlast modifiedÓ timestamp, " & Â
					"so I cannot determine whether they are newer than a corresponding item in the keychain. " & Â
					"What should I do with such items when they match an item in the keychain?" buttons {"Skip Items", "Update Keychain"} Â
					default button "Skip Items" with icon note
				
				if the button returned of the result is "Update Keychain" then
					set override to true
				end if
				
				exit repeat
				
			end if
			
		end repeat
		
		repeat with rec in (a reference to pItems)
			
			if rec's |class| is "genp" then
				
				set ts to timestampGenericPassword(keychain, rec's account, rec's |where|)
				
				if ts is missing value or rec's |modified| is greater than ts or (rec's |modified| is "" and override) then
					addGenericPassword(true, Â
						keychain, Â
						rec's account, Â
						rec's |where|, Â
						rec's label, Â
						rec's comment, Â
						rec's |kind|, Â
						rec's type, Â
						rec's creator, Â
						rec's |password|)
				end if
				
			else if rec's |class| is "inet" then
				
				set w to decodeURL(rec's |where|)
				set ptcl to encodeProtocol(w's protocol)
				set ts to timestampInternetPassword(keychain, rec's account, w's server, w's |path|, w's |port|, ptcl, rec's domain, rec's authtype)
				
				if ts is missing value or rec's |modified| is greater than ts or (rec's |modified| is "" and override) then
					addInternetPassword(true, Â
						keychain, Â
						rec's account, Â
						w's server, Â
						w's |path|, Â
						w's |port|, Â
						ptcl, Â
						rec's domain, Â
						rec's authtype, Â
						rec's label, Â
						rec's comment, Â
						rec's |kind|, Â
						rec's type, Â
						rec's creator, Â
						rec's |password|)
				end if
				
			end if
			
		end repeat
		
	end script
	
	run KeychainImporter
	
end toKeychain


(*!
	@abstract
		Displays an error dialog.
	@param
		msg <em>[text]</em> The error message.
	@return
		Nothing.
*)
on criticalDialog(msg)
	
	activate
	display dialog Â
		Â
			"This script will be terminated prematurely because the following error has occurred: " & return & return & msg Â
		buttons {"Gosh!"} default button 1 with title "Fatal error" with icon stop Â
		giving up after 30
	
end criticalDialog


(*!
	@abstract
		Unlocks the given keychain.
	@discussion
		Uses the <tt>security</tt> tool to unlock the specified keychain.
		Prompts for a password as necessary.
	@param
		keychain (<em>alias</em> | <em>file</em> | <em>text</em>) The absolute path to a keychain file.
	@return
		Nothing.
	@throws
		ÒUser cancelledÓ error if the keychain cannot be unlocked (e.g.,
		because the password is wrong).
*)
on unlockKeychain(keychain)
	
	try
		do shell script "security -q unlock-keychain -u " & quoted form of POSIX path of the keychain
	on error errMsg number 128
		error errMsg number -128
	end try
	
end unlockKeychain


(*!
	@abstract
		Determines whether a generic password exists in a keychain.
	@discussion
		TODO
	@param
		keychain (<em>alias</em> | <em>file</em> | <em>text</em>)
		The absolute path to a keychain file. 
	@param
		account (<em>text</em>) the account field of the password item.
	@param
		service (<em>text</em>) the service field of the password item.
	@return
		(<em>text</em>) The last modification time of the given password item,
		or <tt>missing value</tt> if the item does not exist in the keychain.
	@throws
		Nothing.
*)
on timestampGenericPassword(keychain, account, service)
	
	try
		
		set PasswordItem's rawData to Â
			do shell script Â
				"security -q find-generic-password -a " & ansiQuoted(account) & Â
				" -s " & ansiQuoted(service) & " " & quoted form of POSIX path of the keychain
		
		PasswordItem's attribute("mdat")
		
	on error number 44 -- Not found
		missing value
	end try
	
end timestampGenericPassword


(*!
	@abstract
		Determines whether an internet password exists in a keychain..
	@param
		keychain (<em>alias</em> | <em>file</em> | <em>text</em>) The absolute path to a keychain file.
	@param
		account <em>[text]</em> An account name.
	@param
		server <em>[text]</em> TODO.
	@param
		path <em>[text]</em> TODO.
	@param
		port <em>[text]</em> TODO.
	@param
		protocol <em>[text]</em> TODO.
	@param
		domain <em>[text]</em> TODO.
	@param
		authtype <em>[text]</em> TODO.
	@return
		(<em>text</em>) The last modification time of the given password item,
		or <tt>missing value</tt> if the item does not exist in the keychain.
	@throws
		Nothing.
*)
on timestampInternetPassword(keychain, account, server, |path|, |port|, protocol, domain, authtype)
	
	set {ptcl, atyp} to {"", "", ""}
	
	try
		if protocol's length is 4 then
			set ptcl to " -r " & quoted form of protocol & " "
		end if
		
		if authtype's length is 4 then
			set atyp to " -t " & quoted form of reversetext(authtype) & " "
		end if
		
		set PasswordItem's rawData to Â
			do shell script "security -q find-internet-password -a " & ansiQuoted(account) & Â
				" -s " & ansiQuoted(server) & " -p " & ansiQuoted(|path|) & " -P " & ansiQuoted(|port|) & Â
				" -d " & ansiQuoted(domain) & ptcl & atyp & " " & quoted form of POSIX path of the keychain
		
		PasswordItem's attribute("mdat")
		
	on error number 44 -- Not found
		missing value
	end try
	
end timestampInternetPassword


(*!
	@abstract
		Adds a generic password to the specified keychain.
	@discussion
		TODO
	@param
		TODO
	@return
		TODO
	@throws
		TODO
*)
on addGenericPassword(update, keychain, account, service, label, comment, |kind|, type, creator, |password|)
	
	set cmd to Â
		"security -q add-generic-password -a " & ansiQuoted(account) & " -s " & ansiQuoted(service) Â
		& " -w " & ansiQuoted(|password|)
	
	set options to ""
	
	if label is "" then
		set options to options & " -l " & ansiQuoted(service)
	else
		set options to options & " -l " & ansiQuoted(label)
	end if
	
	set options to options & " -j " & ansiQuoted(comment) & " -D " & ansiQuoted(|kind|)
	
	if type's length is 4 then
		set options to options & " -C " & quoted form of type
	end if
	
	if creator's length is 4 then
		set options to options & " -c " & quoted form of creator
	end if
	
	if update then
		set cmd to cmd & " -U"
	end if
	
	do shell script cmd & options & " " & quoted form of POSIX path of keychain
	
end addGenericPassword


(*!
	@abstract
		Adds an internet password to the specified keycain.
	@discussion
		TODO
	@param
		TODO
	@return
		TODO
	@throws
		TODO
*)
on addInternetPassword(update, keychain, account, server, |path|, |port|, protocol, domain, authtype, label, comment, |kind|, type, creator, |password|)
	
	set cmd to Â
		"security -q add-internet-password -a " & ansiQuoted(account) & " -s " & ansiQuoted(server) Â
		& " -w " & ansiQuoted(|password|) & " -p " & ansiQuoted(|path|) & " -d " & ansiQuoted(domain)
	
	if |port| is not "" then
		set cmd to cmd & " -P " & quoted form of |port|
	end if
	
	if protocol's length is 4 then
		set cmd to cmd & " -r " & quoted form of protocol
	end if
	
	if authtype's length is 4 then
		set cmd to cmd & " -t " & quoted form of reversetext(authtype)
	end if
	
	set options to ""
	
	if label is "" then
		set options to options & " -l " & ansiQuoted(service)
	else
		set options to options & " -l " & ansiQuoted(label)
	end if
	
	set options to options & " -j " & ansiQuoted(comment) & " -D " & ansiQuoted(|kind|)
	
	if type's length is 4 then
		set options to options & " -C " & quoted form of type
	end if
	
	if creator's length is 4 then
		set options to options & " -c " & quoted form of creator
	end if
	
	if update then
		set cmd to cmd & " -U"
	end if
	
	try
		
		do shell script cmd & options & " " & quoted form of POSIX path of the keychain
		
	on error number 45 -- Item exists
		
		-- For some unknown reason (a bug?), an internet password cannot be updated
		-- when additional options are given together with -U (not sure if this is still
		-- the case in Sierra). In this case, try to update only the password:
		if update then
			do shell script cmd & " " & quoted form of POSIX path of the keychain
		else
			error number 45
		end if
		
	end try
	
end addInternetPassword


(*!
	@abstract
		Returns a textual dump of the given keychain.
	@discussion
		Works even when the keychain is locked. Never prompts for passwords.
	@param
		keychain (<em>alias</em> | <em>file</em> | <em>text</em>)
		The absolute path to a keychain file.
	@return
		<em>[text]</em> A textual keychain dump (without passwords).
*)
on dumpKeychainWithoutPasswords(keychain)
	
	do shell script "security -q dump-keychain " & quoted form of POSIX path of the keychain
	
end dumpKeychainWithoutPasswords


(*!
	@abstract
		Returns a textual dump of the given keychain, including sensitive data.	
	@discussion
		The keychain should be unlocked.
		The dump is written into a plain text file, so be careful where you write it!
	@param
		keychain (<em>alias</em> | <em>file</em> | <em>text</em>)
		The absolute path to a keychain file.
	@param
		dumpPath (<em>alias</em> | <em>file</em> | <em>text</em>)
		The absolute path of the keychain dump.
	@param
		mode <em>[text]</em> Can be <tt>Allow</tt> or <tt>Always Allow</tt>.
	@return
		Nothing.
	@throws
		TODO.
*)
on dumpKeychainWithPasswords(keychain, dumpPath, mode)
	
	-- Run security in the background and redirect the output to a file
	-- TODO: DUMP ACLs?
	do shell script Â
		"security -q dump-keychain -d " & quoted form of POSIX path of the keychain & " &>" & quoted form of dumpPath & " &"
	
	delay 0.5 -- Wait a bit for SecurityAgent to start
	
	repeat
		
		try
			
			allowSecurityAccess(mode)
			delay 0.2 -- Wait for the next SecurityAgent process
			
		on error
			
			try -- to wait a bit if security is still running
				
				do shell script "ps -x -o comm | grep ^security$" -- Exit code 1 if grep fails to match
				delay 1
				
			on error
				exit repeat
			end try
			
		end try
		
	end repeat
	
	readUTF8File(dumpPath)
	
end dumpKeychainWithPasswords


(*!
	@abstract
		Dismisses a SecurityAgent's dialog by pressing the specified button.
	@discussion
		It is recommended that you allow this script to control your computer
		in System Preferences > Security & Privacy > Accessibility,
		otherwise you will be prompted with a dialog for each item.		
	@param
		mode <em>[text]</em> Can be <tt>Allow</tt> or <tt>Always Allow</tt>.
	@return
		Nothing.
	@throws
		Nothing.
*)
on allowSecurityAccess(mode)
	
	tell application "System Events"
		tell process "SecurityAgent"
			click button mode of window 1
		end tell
	end tell
	
end allowSecurityAccess


(*!
	@abstract
		Encodes an Internet protocol's name in a format that <tt>security</tt> understands.		
	@param
		p <em>[text]</em> The name of a protocol (e.g., <tt>https</tt>).
	@return
		The encoded protocol's name (e.g., <tt>htps</tt>),
		or the protocol's name itself if it cannot be encoded.
	@throws
		Nothing.
*)
on encodeProtocol(p)
	
	if p's length is 3 then
		p & " "
	else if p is "https" then
		"htps"
	else if p is "pop" then
		"pop3"
	else if p is "telnet" then
		"teln"
	else
		p
	end if
	
end encodeProtocol


(*!
	@abstract
		Handlers to manipulate a password item as dumped by the <tt>security</tt> tool.
	@discussion
		TODO.
*)
script PasswordItem
	
	property rawData : missing value
	
	(*!
		@abstract
			Parses a raw record as output from a <tt>security</tt> dump.
		@discussion
			TODO.
		@throws
			An error if the item cannot be parsed.
	*)
	on parse()
		
		if my rawData does not contain "class: \"genp\"" and my rawData does not contain "class: \"inet\"" then
			error "Not a generic or internet password." number ERR_NOT_PASSWORD_ITEM
		end if
		
		set type to my attribute("type")
		
		if type is "note" and not EXPORT_SECURE_NOTES then
			error "Secure note not exported." number ERR_NOT_PASSWORD_ITEM
		end if
		
		if type is "note" then
			set |password| to my decodeSecureNote()
		else
			set |password| to my attribute("data")
		end if
		
		set label to my attribute("0x00000007")
		set account to my attribute("acct")
		set comment to my attribute("icmt")
		set created to my attribute("cdat")
		set |modified| to my attribute("mdat")
		set |kind| to my attribute("desc")
		set creator to my attribute("crtr")
		
		if my rawData contains "class: \"genp\"" then
			
			set |class| to "genp"
			set |where| to my attribute("svce")
			set {domain, authtype} to {"", ""} -- Not meaningful for generic passwords
			
		else -- internet password
			
			set |class| to "inet"
			set server to my attribute("srvr")
			set |path| to my attribute("path")
			set protocol to my attribute("ptcl") -- Either a four-letter code or 0x00000000
			
			if protocol is not "0" then
				set protocol to my decodeProtocol(protocol) & "://"
			else
				set protocol to ""
			end if
			
			set |port| to my attribute("port")
			
			if |port| is not "0" then
				set |port| to ":" & |port|
			else
				set |port| to ""
			end if
			
			set |where| to protocol & server & |path| & |port|
			set domain to my attribute("sdmn")
			
			-- Possible authentication types are:
			-- 'ntlm' (NTLM), 'msna' (MSN), 'dpaa' (DPA), 'rpaa' (RPA), 'http', (HTTP Basic),
			-- 'httd' (HTTP Digest), 'form' (HTML Form), 'dflt' (Default), '0' (any)
			set authtype to my attribute("atyp")
			
		end if
		
		return {|where|, account, |password|, label, comment, created, |modified|, |kind|, type, domain, authtype, |class|, creator}
		
	end parse
	
	
	(*!
		@abstract
			Returns the value of the given field.
		@discussion
			TODO
	*)
	on attribute(field)
		
		set type to my fieldtype(field)
		
		if field is "data" then
			set theKey to {"data:" & LF, "data:" & CR}
		else if field starts with "0x" then
			set theKey to field & " <" & type & ">=" -- E.g., 0x00000007 <blob>=
		else
			set theKey to quote & field & quote & "<" & type & ">=" -- E.g., "acct"<blob>=
		end if
		
		set v to textBetween(my rawData, theKey, {LF, CR}) as text
		
		if v starts with "0x" then
			my decodeValue(v, type)
		else
			cleanupValue(v)
		end if
		
	end attribute
	
	
	(*!
		@abstract
			TODO
		@discussion
			TODO
	*)
	on fieldtype(field)
		
		if field starts with "0x" or field is in {"acct", "atyp", "data", "desc", "gena", "icmt", "path", "prot", "sdmn", "srvr", "svce"} then
			"blob"
		else if field is in {"cdat", "mdat"} then
			"timedate"
		else if field is in {"crtr", "port", "ptcl", "type"} then
			"uint32"
		else if field is in {"cusi", "invi", "nega", "scrp"} then
			"sint32"
		else
			missing value
		end if
		
	end fieldtype
	
	
	(*!
		@abstract
			TODO
		@discussion
			TODO
	*)
	on cleanupValue(v)
		
		if v is "<NULL>" then
			""
		else
			unquote(v)
		end if
		
	end cleanupValue
	
	
	(*!
		@abstract
			Decodes a value of the form Ò0x<hexadecimal string>  "<ascii string>"Ó.
		@discussion
			TODO
	*)
	on decodeValue(v, type)
		
		if type is equal to "blob" then
			textBetweenGreedy(v, quote, quote) -- Note that v may contain quotes
		else if type is equal to "timedate" then
			text 1 thru -6 of textBetweenGreedy(v, quote, quote) -- Timestamps end with "Z\000"
		else if type starts with "uint" then
			hexToDec(text 3 thru -1 of the first item of split(v, {SP, LF})) -- Get the hex part and convert it to decimal
		else
			error "Cannot decode the given data type: " & type
		end if
		
	end decodeValue
	
	
	
	(*!
		@abstract
			Returns the protocol scheme for the given four-letter code.
		@discussion
			FIXME: only the most common protocol's names are decoded.
	*)
	on decodeProtocol(p)
		
		if p ends with " " then -- e.g., 'ftp '
			text 1 thru 3 of p
		else if p is "htps" then
			"https"
		else if p is "pop3" then
			"pop"
		else if p is "teln" then
			"telnet"
		else
			p
		end if
		
	end decodeProtocol
	
	
	(*!
		@abstract
			TODO
		@discussion
			TODO
	*)
	on decodeSecureNote()
		
		set v to textBetween(my rawData, {"data:" & LF, "data:" & CR}, {LF, CR}) as text
		
		if v starts with "0x" then
			
			try
				
				set secureNote to hexToUTF8(textBetween(v, "0x", SP))
				
				if secureNote starts with "<?xml version=" then
					tell application "System Events" to get the value of (make new property list item with data secureNote)
					|note| of the result
				else
					secureNote
				end if
				
			on error
				textBetweenGreedy(v, "<string>", "</string>")
			end try
			
		else
			
			cleanupValue(secureNote)
		end if
		
	end decodeSecureNote
	
end script -- script PasswordItem

(*!
	@abstract
		TODO
	@discussion
		Requires:
		
		1. Fields are quoted;
		2. The first record is the header;
		3. There is no field of the form "\n" (containing just a newline).
		4. There is no field containing the string: quote & quote & separator & quote & quote.
*)
on PasswordItemsFromCSV(source, separator)
	
	script Parser
		
		property passwordItems : {}
		property csvRecords : split(source, quote & LF & quote)
		
		set header to split(the first item of csvRecords, separator)
		
		set {Â
			i_where, Â
			i_account, Â
			i_password, Â
			i_label, Â
			i_comment, Â
			i_class, Â
			i_created, Â
			i_modified, Â
			i_kind, Â
			i_type, Â
			i_domain, Â
			i_authtype, Â
			i_creator} to Â
			{Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value, Â
				missing value}
		
		repeat with i from 1 to count header
			
			set f to item i of header
			
			if f contains "Where" then
				set i_where to i
			else if f contains "Account" then
				set i_account to i
			else if f contains "Password" then
				set i_password to i
			else if f contains "Label" then
				set i_label to i
			else if f contains "Comments" then
				set i_comment to i
			else if f contains "Class" then
				set i_class to i
			else if f contains "Created" then
				set i_created to i
			else if f contains "Modified" then
				set i_modified to i
			else if f contains "Kind" then
				set i_kind to i
			else if f contains "AuthType" then
				set i_authtype to i
			else if f contains "Type" then
				set i_type to i
			else if f contains "Domain" then
				set i_domain to i
			else if f contains "Creator" then
				set i_creator to i
			end if
			
		end repeat
		
		if i_where is missing value then
			error "Cannot process file: mandatory \"Where\" field is missing."
		end if
		
		if i_account is missing value then
			error "Cannot process file: mandatory \"Account\" field is missing."
		end if
		
		repeat with ki in (a reference to the rest of csvRecords)
			
			set rec to split(ki, quote & separator & quote)
			
			set the end of (a reference to passwordItems) to Â
				{|where|:field(rec, i_where), account:field(rec, i_account), |password|:field(rec, i_password), label:field(rec, i_label), comment:field(rec, i_comment), created:field(rec, i_created), |modified|:field(rec, i_modified), |kind|:field(rec, i_kind), type:field(rec, i_type), domain:field(rec, i_domain), authtype:field(rec, i_authtype), |class|:field(rec, i_class), creator:field(rec, i_creator)}
			
			
		end repeat
		
		return passwordItems
		
		
		on field(rec, i)
			
			if i is missing value then
				""
			else
				replace(unquote(chomp(item i of rec)), quote & quote, quote)
			end if
			
		end field
		
	end script
	
	run Parser
	
end PasswordItemsFromCSV


(*!
	@abstract
		TODO
	@discussion
		TODO
*)
on PasswordItemsFromKeychainDump(source)
	
	script Parser
		
		property passwordItems : {FIELDS} -- Header
		property keychainItems : split(source, "keychain: ")
		
		repeat with ki in (a reference to keychainItems)
			
			set PasswordItem's rawData to the contents of ki
			
			try
				
				set the end of (a reference to passwordItems) to PasswordItem's parse()
				
			on error errMsg number ERR_NOT_PASSWORD_ITEM
			end try
			
		end repeat
		
		return my passwordItems
		
	end script
	
	run Parser
	
end PasswordItemsFromKeychainDump


-----------------------------
-- Text-related handlers
-----------------------------

on split(theText, theDelim)
	
	set {tid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, theDelim}
	set theResult to the text items of theText
	set AppleScript's text item delimiters to tid
	return theResult
	
end split


on join(theList, theDelim)
	
	set {tid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, theDelim}
	set theResult to theList as text
	set AppleScript's text item delimiters to tid
	return theResult
	
end join


on replace(theText, old, new)
	
	join(split(theText, old), new)
	
end replace


on reversetext(theText)
	
	(reverse of text items of theText) as text
	
end reversetext


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


-- Returns the text between the first occurrence of leftDelim
-- and the last occurrence of rightDelim. The two delimiters are not
-- necessarily distinct.
-- Example: textBetweenGreedy("AAA \"BBB\"CCC\" DDD", quote, quote)
-- returns "BBB\"CCC".
on textBetweenGreedy(theText, leftDelim, rightDelim)
	
	set t to join(the rest of split(theText, leftDelim), leftDelim)
	
	if t is not "" then
		return join(reverse of rest of reverse of split(t, rightDelim), rightDelim)
	end if
	
	return ""
	
end textBetweenGreedy


on unquote(x)
	
	if x is in {quote, quote & quote} then
		""
	else
		set {l, r} to {1, -1}
		if x starts with quote then set l to 2
		if x ends with quote then set r to -2
		try
			text l thru r of x
		on error
			x
		end try
	end if
	
end unquote


-- Removes trailing newline from a string
on chomp(x)
	
	if x ends with LF then
		try
			text 1 thru -2 of x
		on error -- x is "\n"
			""
		end try
	else
		x
	end if
	
end chomp


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
	
	return s
	
end reversebytes


-- Returns the ANSI-C quoted form of text t.
on ansiQuoted(t)
	
	"$'" & replace(t, "'", "\\'") & "'"
	
end ansiQuoted


-----------------------------------
-- File and URL manipulation
-----------------------------------

on chooseFile(msg, type, defaultLocation)
	
	set theAlias to choose file with prompt msg of type {type} Â
		default location defaultLocation Â
		without invisibles, multiple selections allowed and showing package contents
	
	{basename(theAlias), theAlias}
	
end chooseFile


on readUTF8File(thePath)
	
	read (POSIX file (POSIX path of thePath) as alias) from 1 to eof as Çclass utf8È
	
end readUTF8File


on writeUTF8File(thePath, theData)
	
	set fd to open for access POSIX file (POSIX path of thePath) with write permission
	
	try
		write theData to fd as Çclass utf8È
	on error errMsg number errNum
		close access fd -- Ensure that the file descriptor is released
		error errMsg number errNum
	end try
	
	close access fd
	
end writeUTF8File


(*!
	@abstract
		Check if file exists and, if it does, ask the user what to do.
	@param
		thePath <em>[path]</em> A path specification.
	@return
		Nothing.
	@throws
		ÒUser canceledÓ error if the file exists and
		the user decides not to overwrite it.
*)
on askIfFileExists(thePath)
	
	local fileExists
	
	try
		POSIX file (POSIX path of thePath) as alias
		set fileExists to true
	on error
		set fileExists to false
	end try
	
	if fileExists then
		display alert "File exists" message (POSIX path of thePath) & Â
			" exists. Overwrite?" as warning buttons {"Yes", "No"} default button "No" cancel button "No"
	end if
	
end askIfFileExists


-- Returns the base filename of the given path.
-- Example: basename("HD:Users:me:Downloads:filename.txt") is "filename".
on basename(pathname)
	
	set bn to split(last item of split(POSIX path of pathname, "/"), ".")
	if (count bn) > 1 then return join(items 1 thru -2 of bn, ".")
	return bn as text
	
end basename


on decodeURL(theURL)
	
	set out to {protocol:"", server:"", |path|:"", |port|:""}
	set x to split(theURL, "://")
	
	if (count x) > 2 then
		error "Could not parse the URL: " & theURL
	end if
	
	if (count x) = 2 then
		set {out's protocol, x} to {the first item of x, the rest of x}
	end if
	
	set x to split(x as text, ":")
	
	if (count x) > 2 then
		error "Could not parse the URL: " & theURL
	end if
	
	if (count x) = 2 then
		set {x, out's |port|} to {the first item of x, (the rest of x) as text}
	end if
	
	set x to split(x as text, "/")
	
	if (count x) = 1 then
		set out's server to x as text
	else
		set {out's server, out's |path|} to {the first item of x, "/" & join(the rest of x, "/")}
	end if
	
	return out
	
end decodeURL


on timestamp()
	
	local d
	
	set d to current date
	join({year of d as text, month of d as text, day of d as text, time of d as text}, "-")
	
end timestamp
