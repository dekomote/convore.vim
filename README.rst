###########
Convore.vim
###########

Convore.vim is a vim plugin- reader for convore, in early alpha at the moment.
If you want to try it, put it in your "plugins" folder or :source it.

.. image:: http://i.imgur.com/bC0FZ.png

.. image:: http://i.imgur.com/hAw2o.png

.. image:: http://i.imgur.com/Lm3Bp.png

Usage
=====

You need to set g:convore_user and g:convore_password in your .vimrc

After that, just do ":Convore". That will show you a buffer with a list of your 
groups. Go over a group and hit Return. That will show you a list of the topics
in the group. If you hit Return while on top on a topic, it will list the
messages in that topic.

To get back from messages to topics or from topics to groups, press b when in 
CONVORE buffer.

Group Management
++++++++++++++++

    :ConvoreCreateGroup <group_name> - Creates a public group

    :ConvoreCreatePrivateGroup <group_name> - Creates a private group

after the group is created, the user is directed to the group's display

Topic Management
++++++++++++++++

    :ConvoreCreateTopic <topic_name> - Creates a topic

Note: It's best if you are in a group context while creating a topic. The last 
group listed will be used for the topic. That means, if you are on the display
that lists the messages from a topic, the new topic will be created in the listed
one's parent group.

Directs you to the messages listing of the new topic.

Messages
++++++++

    :ConvoreCreateMessage <message> - Write a message to the current topic
    
    :ConvorePostCurrent - Posts the current buffer, preserving newlines, or
    visual selection - :'<,'>ConvorePostCurrent

Same goes here. The current or last listed topic will be used for the message.


Aditional Notes
===============

The script is in a very early stage. Feel free to suggest stuff, comment
and critique.

I would really appreciate help with highlighting.

You need vim compiled with +python support.

