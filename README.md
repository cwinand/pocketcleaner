# pocketcleaner [incomplete]
Command line Ruby program to move my backlog of articles from Pocket into Evernote

Pocket is my read later app of choice, but if an article is worth saving for reference I keep it in Evernote. I needed a way to bulk-move a backlog of these reference articles since doing it one by one was ridiculous. I wrote it in Ruby because I wanted to practice Ruby.


##Workflow
- Save articles from anywhere to Pocket
- If article is worth saving, favorite it
- When done reading, tag it and archive it
- On a regular basis (I do it once every week or two) run this script to move the favorited articles to Evernote, unfavorite them, and archive them if not archived yet

##Nitty gritty
For now you must have a developer account for both services so you can run this using your api key. Hopefully will be improving this soon to run through a 'normal' authentication flow.
Otherwise run from terminal:
````
$ ruby /path/to/pocketcleaner.rb "pocketapikey" "evernoteapikey"
````
