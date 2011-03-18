###########
Convore.vim
###########

Convore.vim is a vim plugin- reader for convore, in early alpha at the moment.
If you want to try it, put it in your "plugins" folder or :source it.

Usage
=====

You need to set g:convore_user and g:convore_password in your .vimrc

After that, just do ":Convore". That will show you a buffer with a list of your 
groups. Go over a group and hit Return. That will show you a list of the topics
in the group. If you hit Return while on top on a topic, it will list the
messages in that topic.

Aditional Notes
===============

The script is in a very early stage. Feel free to suggest stuff, comment
and critique.

You need vim compiled with +python support.

