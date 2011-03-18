"=============================================================================
" File: convore.vim
" Author: Dejan Noveski <dr.mote@gmail.com>
" Last Change: 18-Mar-2011.
" Version: 0.2
" WebPage: http://github.com/dekomote/convore.vim
" Description: Reader plugin for https://convore.com
" Usage:
"   Put the script in plugins dir, or :source it.
"   :Convore - Opens your groups list
"   Hit return on top of a group or topic to advance into it. Hit 'b' inside
"   the buffer to go back from messages to topics and from topics to groups.
"
" Notes:
"   Set g:convore_user and g:convore_password in the script or in .vimrc to
"   your convore auth info.
"   Requires vim compiled with +python.
"
"

" Check if vim is compiled with python support.
if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

" Set auth info here if you don't want to set it in .vimrc
" .vimrc overrides this.
if !exists('g:convore_user')
    let g:convore_user = ''
    let g:convore_password = ''
endif

" HTTP request timeout set to 20 seconds. If you have a very very slow
" connection and you have issues with the requests, try bump this number up.
if !exists('g:convore_api_timeout')
    let g:convore_api_timeout = 20
endif

" Everything is displayed in a scratch buffer named CONVORE.
let g:convore_scratch_buffer = 'CONVORE'

" Function that opens or navigates to the scratch buffer.
function! s:ConvoreScratchBufferOpen(name)
    
    let scr_bufnum = bufnr(a:name)
    if scr_bufnum == -1
        exe "new " . a:name 
    else
        let scr_winnum = bufwinnr(scr_bufnum)
        if scr_winnum != -1
            if winnr() != scr_winnum
                exe scr_winnum . "wincmd w"
            endif
        else
            exe "split +buffer" . scr_bufnum
        endif
    endif
    call ConvoreScratchBuffer()
endfunction

" After opening the scratch buffer, this sets some properties for it.
function! ConvoreScratchBuffer()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal buflisted
    setlocal cursorline
    setlocal filetype=rst
endfunction


" Define some python functions here
python << EOF
import urllib2, base64, exceptions, vim 
try:
    import simplejson as json
except ImportError:
    import json

DEFAULT_SCRATCH_NAME = vim.eval('g:convore_scratch_buffer')
USERNAME = vim.eval('g:convore_user')
PASSWORD = vim.eval('g:convore_password')
CONVORE_URL = 'https://convore.com'
GROUPS_LIST_URL = CONVORE_URL + '/api/groups.json'

def request(url):
    """ Simple function for http requests using urllib2 """

    api_timeout = float(vim.eval('g:convore_api_timeout'))

    request = urllib2.Request(url)
    base64auth = base64.encodestring('%s:%s' % (USERNAME, PASSWORD)).replace(
                                '\n', '')
    request.add_header("Authorization", "Basic %s" % base64auth)
    try:
        response = urllib2.urlopen(request, None, api_timeout)
        return json.loads(response.read())
    except exceptions.Exception, e:
        print e
        return None

def scratch_buffer(sb_name = DEFAULT_SCRATCH_NAME):
    """ Opens a scratch buffer from python """
    vim.command("call s:ConvoreScratchBufferOpen('%s')" % sb_name)
EOF


" Function that displays user's groups
" Locally maps <CR> to call ConvoreTopicsList
function! ConvoreGroupsList()
python << EOF

import vim
groups = request(GROUPS_LIST_URL).get("groups")

# Initialize the scratch buffer
scratch_buffer()
del vim.current.buffer[:]
vim.current.buffer[0] = "%s's CONVORE GROUPS" % USERNAME
vim.current.buffer.append(79 * "-")

# Write group info in the buffer
for group in groups:
    group_name = group.get("name").encode('utf-8')
    group_url = CONVORE_URL + group.get("url").encode('utf-8') 
    topics_count = group.get("topics_count")
    unread_count = group.get("unread")
    group_id = group.get("id").encode("utf-8")
    vim.current.buffer.append("%s > Topics: %s | Unread: %s | [%s] (convore_gid:%s)" % (
                            group_name, topics_count, unread_count,
                            group_url, group_id))
    vim.current.buffer.append(79 * "-")
    vim.command("map <buffer> <CR> <Esc>:call ConvoreTopicsList()<CR>")

EOF
endfunction

" Function that displays 
function! ConvoreTopicsList(...)
python << EOF
import vim

if int(vim.eval("a:0")) > 1:
    group_id = vim.eval("a:1")
    group_name = vim.eval("a:2")
else:
    line = vim.current.line
    group_re = re.search("\(convore_gid:([0-9]+)\)", line)
    if group_re:
        gn_re = re.search("^(.*) > Topics: [0-9]+", line)
        group_name = gn_re.group(1)
        group_id = group_re.group(1)

if group_name and group_id:
    vim.command("let g:convore_current_group_id=%s" % group_id)
    vim.command("let g:convore_current_group_name='%s'" % group_name)
    topics = request(CONVORE_URL + "/api/groups/%s/topics.json" % group_id).get("topics")
    scratch_buffer()
    del vim.current.buffer[:]
    vim.current.buffer[0] = 'TOPICS IN GROUP "%s"' % group_name 
    vim.current.buffer.append(79 * "-")
    for topic in topics:
        topic_name = topic.get("name").encode('utf-8')
        message_count = topic.get("message_count")
        unread_count = topic.get("unread")
        topic_id = topic.get("id").encode("utf-8")
        topic_url = CONVORE_URL + topic.get("url").encode("utf-8") 
        vim.current.buffer.append("%s > Messages: %s | Unread: %s | [%s] (convore_tid:%s)" % (
                                topic_name, message_count, unread_count,
                                topic_url, topic_id))
        vim.current.buffer.append(79 * "-")
        vim.command("map <buffer> <CR> <Esc>:call ConvoreMessagesList()<CR>")
        vim.command("map <buffer> b <Esc>:call ConvoreGroupsList()<CR>")
EOF
endfunction

function! ConvoreMessagesList(...)
python << EOF
import vim
import re, datetime

line = vim.current.line
topic_re = re.search("\(convore_tid:([0-9]+)\)", line)
if topic_re:
    tn_re = re.search("^(.*) > Messages: [0-9]+", line)
    topic_name = tn_re.group(1)
    topic_id = topic_re.group(1)

    vim.command("let g:convore_current_topic_id=%s" % topic_id)
    vim.command("let g:convore_current_topic_name='%s'" % topic_name)
    messages = request(CONVORE_URL + "/api/topics/%s/messages.json" % topic_id).get("messages")
    scratch_buffer()
    del vim.current.buffer[:]
    vim.current.buffer[0] = 'MESSAGES IN TOPIC "%s"' % topic_name 
    vim.current.buffer.append(79 * "-")
    for message in messages:
        body = message.get("message").encode('utf-8').replace("\n", " ")
        user = message.get("user").get("username").encode("utf-8")        
        date_created = datetime.datetime.fromtimestamp(message.get("date_created")).strftime("%a %b %d %H:%M:%S %Y")
        stars = message.get("stars")
        message_id = message.get("id").encode("utf-8")
        vim.current.buffer.append(body)
        vim.current.buffer.append("%s | %s | %s" % (user, date_created, ", ".join(["★" + star.get("user").get("username").encode("utf-8") for star in stars])))
        vim.current.buffer.append(79 * "-")
        vim.command("map <buffer> <CR> <Esc>:call ConvoreMessagesList()<CR>")
        vim.command("map <buffer> b <Esc>:call ConvoreTopicsList(g:convore_current_group_id, g:convore_current_group_name)<CR>")
EOF
endfunction

command! -nargs=0 Convore call ConvoreGroupsList()
