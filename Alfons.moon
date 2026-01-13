tasks:
	icons: =>
		sh "convert icons/icon.svg -resize 48x48 icons/icon.png"
		sh "convert icons/icon.svg -resize 256x256 icons/icon.jpg"
	clean: =>
		delete "vnds/" if fs.exists "vnds/"
	compile: =>
		tasks.clean!
		copy "src/", "vnds/"
		for file in wildcard "vnds/**.moon"
			print file
			sh "moonc #{file}"
			delete file
	run: =>
		tasks.compile!
		sh "love vnds"
	test: => --runs off of src directly
		sh "busted -C src ../spec"
	build: =>
		tasks.compile!
		sh "love-release -W -M --uti 'me.octonezd.vnds' build vnds/"

