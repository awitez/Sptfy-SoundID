on adding folder items to theAttachedFolder after receiving addedItems

	set mrswatson to "/usr/local/bin/mrswatson64" -- it's an Intel bin but so is SoundID VST2
	set ffmpeg to "/opt/homebrew/bin/ffmpeg" -- brew install ffmpeg
	set sox to "/opt/homebrew/bin/sox" -- brew install sox
	set wget to "/opt/homebrew/bin/wget" -- brew install wget
	set mp4art to "/opt/homebrew/bin/mp4art" -- brew install mp4v2
	set bpm to "/opt/homebrew/bin/bpm" -- brew install bpm-tools

	set baseDir to "/Users/andreas/"
	set soundIdDir to baseDir & "Documents/temp/SoundID/"
	set musicDir to baseDir & "Documents/temp/music/"
	set tmpDir to baseDir & "Documents/temp/"
	set tmpFile to tmpDir & "audiohijack.wav" -- setting in Audio Hijack

	set startSpotify to "open -g -b com.rogueamoeba.audiohijack " & baseDir & "Library/CloudStorage/Dropbox/code/AppleScript/Spotify/StartSpotify.ahcommand"
	set stopSpotify to "open -g -b com.rogueamoeba.audiohijack " & baseDir & "Library/CloudStorage/Dropbox/code/AppleScript/Spotify/StopSpotify.ahcommand"

	set plugin to "'SoundID Reference VST Plugin'," & baseDir & "Library/CloudStorage/Dropbox/code/AppleScript/Spotify/SoundID.fxp"
	set soundIdComment to "'processed with Sonarworks #SoundID Reference Headphone - 1MORE Quad Driver E1010'"

	tell application "Finder"
		set myDir to name of theAttachedFolder
	end tell

	-- here are the ID files
	set thisDir to baseDir & "Library/CloudStorage/Dropbox/music/" & myDir & "/"

	-- are we running from an album folder? -> get the trackIDs from the album-tracks
	if (myDir contains "album") then
		set myList to {}
	
		repeat with i from 1 to number of items in addedItems
			set thisItem to item i of addedItems
			
			tell application "Finder" to set fileNameExt to name of thisItem
			set AppleScript's text item delimiters to "."
			set fileExt to "." & last text item of fileNameExt
			set AppleScript's text item delimiters to fileExt
			set albumID to first text item of fileNameExt
			
			set albumURL to "spotify:album:" & albumID
			--set albumURL to "spotify:album: 4ePl0meknOkJ892O9yszEY"

			do shell script "open -ja Spotify.app"

			tell application "Spotify"
				set sound volume to 0
				set shuffling to false

				play track albumURL
				delay 1
				
				set trackSpotifyID to id of current track
				set trackAlbum to album of current track
				set trackArtwork to artwork url of current track
				set trackArtist to artist of current track

				set end of myList to text 15 thru end of trackSpotifyID
				next track
				delay 1
				
				try
					repeat while not ((track number of current track is 1) and (disc number of current track is 1))
						set trackSpotifyID to id of current track
						
						set end of myList to text 15 thru end of trackSpotifyID
						next track
						delay 1
					end repeat
				end try
				
				pause
				set sound volume to 100
			end tell
			
			if trackAlbum contains "/" then
				set trackAlbum to replaceChars(trackAlbum, "/", ":")
			end if

			do shell script "mkdir -p " & tmpDir & quoted form of trackAlbum
			
			repeat with theItem in myList
				set itemFile to  quoted form of (tmpDir & trackAlbum & "/" & theItem & ".url")
				do shell script "touch " & itemFile
				do shell script "echo \"[InternetShortcut]\nURL=https://open.spotify.com/track/" & theItem & "\" > " & itemFile
			end repeat
			
			set myList to {}

			-- get album cover
			set tmpArt to quoted form of (tmpDir & trackAlbum & "/" & trackArtist & " - " & trackAlbum & ".jpg")
			set theScript to (wget & " -O " & tmpArt & " " & trackArtwork)
			do shell script theScript

			-- cleanup
			do shell script "mv " & thisDir & albumID & ".url " & thisDir & "done"

		end repeat
		return -- leave the script
	end if

	repeat with i from 1 to number of items in addedItems
	
		try
			-- get Spotify track ID from filename
			set thisItem to item i of addedItems

			tell application "Finder" to set fileNameExt to name of thisItem
			set AppleScript's text item delimiters to "."
			set fileExt to "." & last text item of fileNameExt
			set AppleScript's text item delimiters to fileExt
			set trackID to first text item of fileNameExt

			set trackURL to "spotify:track:" & trackID
			--set trackURL to "spotify:track:3eyusi7FLZZW3TjZoCgwVf"

			-- kill Audio Hijack if running (or hanging)
			tell application "System Events"
				set ProcessList to name of every process
				if "Audio Hijack" is in ProcessList then
					set ThePID to unix id of process "Audio Hijack"
					do shell script "kill -KILL " & ThePID
					delay 1
				end if
			end tell

			-- delete all temp files
			try
				set theScript to ("rm " & tmpDir & "audiohijack*.wav") 
				do shell script theScript
			end try

			do shell script "open -ja Spotify.app"
			delay 2 -- wait for startup

			do shell script "open -ja \"Audio Hijack.app\"" -- -ja: open app hidden, -ga open in background
			delay 2

			tell application "Spotify"
				set sound volume to 100
				set repeating to false
				set shuffling to false
				
				do shell script startSpotify
				delay 2
				play track trackURL
				delay 2

				set trackName to name of current track
				set trackNumber to track number of current track
				set trackDiscNumber to disc number of current track
				set trackArtist to artist of current track
				set trackAlbumArtist to album artist of current track
				set trackLength to duration of current track -- in milliseconds!
				set trackAlbum to album of current track
				set trackArtwork to artwork url of current track
				set trackSpotifyID to id of current track

			end tell

			delay ((trackLength/1000)-2) -- wait till track is recorded
			do shell script stopSpotify

			try
				tell application "Audio Hijack"
					quit
				end tell
			end try
			
			try
				tell application "Spotify"
					quit
				end tell
			end try

			-- get bpm of track
			set theScript to sox & " " & tmpFile & " -t raw -r 44100 -e float -c 1 - | " & bpm
			set trackBPM to do shell script theScript

			-- ffmpeg options: Apple Lossless Codec and metadata
			set ffOptions to " -c:a alac -metadata title=" & quoted form of trackName & " -metadata artist=" & quoted form of trackArtist & " -metadata album_artist=" & quoted form of trackAlbumArtist & " -metadata disc=" & trackDiscNumber & " -metadata tmpo=" & trackBPM & " -metadata track=" & trackNumber & " -metadata album=" & quoted form of trackAlbum 

			-- no slashes in filename
			if trackAlbum contains "/" then
				set trackAlbum to my replaceChars(trackAlbum, "/", ":") -- add 'my' cause we are running the handle from within a handle 
			end if

			if trackArtist contains "/" then
				set trackArtist to my replaceChars(trackArtist, "/", ":")
			end if
			
			if trackName contains "/" then
				set trackName to my replaceChars(trackName, "/", ":")
			end if

			-- get album cover
			set tmpArt to quoted form of (tmpDir & trackArtist & " - " & trackAlbum & ".jpg")
			set theScript to (wget & " -O " & tmpArt & " " & trackArtwork)
			do shell script theScript

			-- process track with soundID reference VST plugin
			set tmpFileProc to quoted form of (tmpDir & trackName & "_soundID.wav")
			set theScript to mrswatson & " -p " & plugin & " -i " & tmpFile & " -o " & tmpFileProc
			do shell script theScript

			-- output as Apple lossless 24bit
			-- recorded track
			do shell script "mkdir -p " & quoted form of (musicDir & trackArtist & " - " & trackAlbum)
			set outFile to quoted form of (musicDir & trackArtist & " - " & trackAlbum & "/" & trackDiscNumber & " - " & trackNumber & " " & trackName & ".m4a")
			set theScript to ffmpeg & " -y -i " & tmpFile & ffOptions & " " & outFile
			do shell script theScript
		
			set theScript to mp4art & " --add " & tmpArt & " " & outFile
			do shell script theScript
		
			-- soundID processed track
			do shell script "mkdir -p " & quoted form of (soundIdDir & trackArtist & " - " & trackAlbum)
			set outFile to quoted form of (soundIdDir & trackArtist & " - " & trackAlbum & "/" & trackDiscNumber & " - " & trackNumber & " " & trackName & ".m4a")
			set theScript to ffmpeg & " -y -i " & tmpFileProc & ffOptions & " -metadata comment=" & soundIdComment & " " & outFile
			do shell script theScript
		
			set theScript to mp4art & " --add " & tmpArt & " " & outFile
			do shell script theScript

			-- cleanup
			try 
				do shell script "rm " & tmpFile -- recorded file from Spotify
				do shell script "rm " & tmpFileProc -- prcessed wav with soundID
				do shell script "rm " & tmpArt -- album art
				do shell script "mv " & thisDir & trackID & ".url " & thisDir & "done" -- url file from Spotify
			end try
		end try
	end repeat
end adding folder items to

on replaceChars(thisText, searchString, replacementString)
	set AppleScript's text item delimiters to the searchString
	set the itemList to every text item of thisText
	set AppleScript's text item delimiters to the replacementString
	set thisText to the itemList as string
	set AppleScript's text item delimiters to ""
	return thisText
end replaceChars