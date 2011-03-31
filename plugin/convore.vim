"=============================================================================
" File: convore.vim
" Author: Dejan Noveski <dr.mote@gmail.com>
" Last Change: 21-Mar-2011.
" Version: 0.4
" WebPage: http://github.com/dekomote/convore.vim
" Description: Reader plugin for https://convore.com
" Usage:
"   Put the script in plugins dir, or :source it.
"   :Convore - Opens your groups list
"   Hit return on top of a group or topic to advance into it. Hit 'b' inside
"   the buffer to go back from messages to topics and from topics to groups.
"
"   Check README for detailed instructions
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
import urllib2, base64, exceptions, vim, urllib 
try:
    import simplejson as json
except ImportError:
    import json

DEFAULT_SCRATCH_NAME = vim.eval('g:convore_scratch_buffer')
USERNAME = vim.eval('g:convore_user')
PASSWORD = vim.eval('g:convore_password')
CONVORE_URL = 'https://convore.com'
GROUPS_LIST_URL = CONVORE_URL + '/api/groups.json'

def request(url, post_data = None):
    """ Simple function for http requests using urllib2 """

    api_timeout = float(vim.eval('g:convore_api_timeout'))

    request = urllib2.Request(url)
    base64auth = base64.encodestring('%s:%s' % (USERNAME, PASSWORD)).replace(
                                '\n', '')
    request.add_header("Authorization", "Basic %s" % base64auth)
    try:
        if post_data:
            post_data = urllib.urlencode(post_data)
        response = urllib2.urlopen(request, post_data, api_timeout)
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
vim.current.buffer.append(79 * "#")

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
import re

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
    vim.current.buffer.append(79 * "#")
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
    vim.command("command! -nargs=1 ConvoreCreateTopic call ConvoreCreateTopic('%s', '<args>')" % group_id)
EOF
endfunction

function! ConvoreMessagesList(...)
python << EOF
import vim
import re, datetime

if int(vim.eval("a:0")) > 1:
    topic_id = vim.eval("a:1")
    topic_name = vim.eval("a:2")
else:
    line = vim.current.line
    topic_re = re.search("\(convore_tid:([0-9]+)\)", line)
    if topic_re:
        tn_re = re.search("^(.*) > Messages: [0-9]+", line)
        topic_name = tn_re.group(1)
        topic_id = topic_re.group(1)

if topic_name and topic_id:
    vim.command("let g:convore_current_topic_id=%s" % topic_id)
    vim.command("""let g:convore_current_topic_name="%s" """ % topic_name)
    messages = request(CONVORE_URL + "/api/topics/%s/messages.json" % topic_id).get("messages")
    scratch_buffer()
    del vim.current.buffer[:]
    vim.current.buffer[0] = 'MESSAGES IN TOPIC ' + vim.eval("g:convore_current_group_name") + " > " + topic_name
    vim.current.buffer.append(79 * "#")
    for message in messages:
        body = message.get("message").encode('utf-8')
        user = message.get("user").get("username").encode("utf-8")        
        date_created = datetime.datetime.fromtimestamp(message.get("date_created")).strftime("%a %b %d %H:%M:%S %Y")
        stars = message.get("stars")
        message_id = message.get("id").encode("utf-8")
        vim.current.buffer.append(body.split("\n"))
        vim.current.buffer.append("%s | %s | %s" % (user, date_created, ", ".join(["★" + star.get("user").get("username").encode("utf-8") for star in stars])))
        vim.current.buffer.append(79 * "-")
    vim.command("map <buffer> b <Esc>:call ConvoreTopicsList(g:convore_current_group_id, g:convore_current_group_name)<CR>")
    vim.command("command! -nargs=1 ConvoreCreateMessage call ConvoreCreateMessage('%s', '<args>')" % topic_id)
    vim.command("command! -nargs=* -range=0 ConvorePostCurrent call ConvorePostCurrent(<line1>, <line2>, <count>, '%s')" % topic_id)
    vim.command("map <buffer> <CR> <Esc>ConvoreCreateMessage ")
EOF
endfunction


function! ConvoreCreateGroup(name, kind)
python << EOF
import vim

group_name = vim.eval("a:name")
group_kind = vim.eval("a:kind")
create_url = CONVORE_URL + '/api/groups/create.json'

resp = request(create_url, {"name": group_name, "kind": group_kind})
if resp:
    try:
        group_id = resp.get("group").get("id").encode("utf-8")
        vim.command("call ConvoreTopicsList('%s', '%s')" % (str(group_id), str(group_name),))
    except Exception, e:
        print e
EOF
endfunction


function! ConvoreCreateTopic(group_id, name)
python << EOF
import vim

group_id = vim.eval("a:group_id")
topic_name = vim.eval("a:name")
create_url = CONVORE_URL + '/api/groups/%s/topics/create.json' % group_id

resp = request(create_url, {"name": topic_name, "group_id": group_id})
if resp:
    try:
        topic_id = resp.get("topic").get("id").encode("utf-8")
        vim.command("call ConvoreMessagesList('%s', '%s')" % (str(topic_id), str(topic_name),))
    except Exception, e:
        print e
EOF
endfunction

function! ConvoreCreateMessage(topic_id, message)
python << EOF
import vim

topic_id = vim.eval("a:topic_id")
message = vim.eval("a:message")
create_url = CONVORE_URL + '/api/topics/%s/messages/create.json' % topic_id

resp = request(create_url, {"message": message, "topic_id": topic_id})
if resp:
    try:
        vim.command("call ConvoreMessagesList('%s', '%s')" % (str(topic_id), str(vim.eval("g:convore_current_topic_name")),))
    except Exception, e:
        print e
EOF
endfunction

function! ConvorePostCurrent(line1, line2, count, topic_id)
python << EOF
import vim
rng_start = int(vim.eval('a:line1')) - 1
rng_end = int(vim.eval('a:line2'))
if int(vim.eval('a:count')):
    code = '\n'.join(vim.current.buffer[rng_start:rng_end])
else:
    code = '\n'.join(vim.current.buffer)

vim.command("call ConvoreCreateMessage('%s', '%s')" % (topic_id, code.encode("utf-8").replace("'","`"),))
EOF
endfunction

command! -nargs=0 Convore call ConvoreGroupsList()
command! -nargs=1 ConvoreCreateGroup call ConvoreCreateGroup("<args>", "public")
command! -nargs=1 ConvoreCreatePrivateGroup call ConvoreCreateGroup("<args>", "private")
