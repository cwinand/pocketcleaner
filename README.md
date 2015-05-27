# pocketcleaner
Command line Ruby program to move my backlog of articles from Pocket into Evernote

Pocket is my read later app of choice, but if an article is worth saving for reference I keep it in Evernote. I needed a way to bulk-move a backlog of these reference articles since doing it one by one was ridiculous. I wrote it in Ruby because I wanted to practice Ruby.


##Workflow
- Save articles from anywhere to Pocket
- If article is worth saving, favorite it
- When done reading, tag it and archive it
- On a regular basis (I do it once every week or two) run this script to move the favorited articles to Evernote, unfavorite them, and archive them if not archived yet

##Nitty gritty
For now you must have a developer account for both services so you can run this using your api key.
- Go to http://getpocket.com/developer/apps/ and create an application & get a consumer key.
- Go to https://www.evernote.com/api/DeveloperToken.action to get your Evernote developer token.

Run from terminal:
````
$ ruby /path/to/pocketcleaner.rb "pocketconsumerkey" "evernotedevelopertoken"
````
**Notes**
- It will ask some questions about changing your items in Pocket - by default it will unfavorite and archive the item. _It is completely non-destructive - everything this program does is reversible_.
- Currently it is mapping my own personal Pocket tags to a specific Evernote Notebook. For example, I will tag something in Pocket with "dev", and when it adds to Evernote it will be in the "Developement Reference" notebook.
- If an item from Pocket has multiple tags, it will ask which tag you'd like to use to map to a notebook.

#Future Plans with no timeframe:
- Use OAuth authentication flow instead of developer tokens, can run in browser
- Have tag to note mapping be based on a config file
- Better error handling for possible cases I haven't seen yet
- Add full text to Evernote note instead of just excerpt provide by Pocket
- Add better methods to work with Pocket items individually