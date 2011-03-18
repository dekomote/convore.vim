if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

if !exists('g:convore_user')
    let g:convore_user = ''
    let g:convore_password = ''
endif

if !exists('g:convore_api_timeout')
    let g:convore_api_timeout = 20
endif

let g:convore_scratch_buffer = 'CONVORE'

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


function! ConvoreScratchBuffer()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal buflisted
    setlocal cursorline
endfunction



python << EOF
import urllib2, base64, exceptions, vim 
import json

DEFAULT_SCRATCH_NAME = vim.eval('g:convore_scratch_buffer')
USERNAME = vim.eval('g:convore_user')
PASSWORD = vim.eval('g:convore_password')
CONVORE_URL = 'https://convore.com'
GROUPS_LIST_URL = CONVORE_URL + '/api/groups.json'

def request(url):
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
    vim.command("call s:ConvoreScratchBufferOpen('%s')" % sb_name)
EOF


function! ConvoreGroupsList()
python << EOF

import vim
groups = request(GROUPS_LIST_URL).get("groups")

scratch_buffer()
del vim.current.buffer[:]
vim.current.buffer[0] = "%s's CONVORE GROUPS" % USERNAME
vim.current.buffer.append(79 * "-")

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

function! ConvoreTopicsList()
python << EOF
import vim
import re

line = vim.current.line
group_re = re.search("\(convore_gid:([0-9]+)\)", line)
if group_re:
    gn_re = re.search("^(.*) > Topics: [0-9]+", line)
    group_name = gn_re.group(1)
    group_id = group_re.group(1)
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
EOF
endfunction

function! ConvoreMessagesList()
python << EOF
import vim
import re, datetime

line = vim.current.line
topic_re = re.search("\(convore_tid:([0-9]+)\)", line)
if topic_re:
    tn_re = re.search("^(.*) > Messages: [0-9]+", line)
    topic_name = tn_re.group(1)
    topic_id = topic_re.group(1)
    messages = request(CONVORE_URL + "/api/topics/%s/messages.json" % topic_id).get("messages")
    scratch_buffer()
    del vim.current.buffer[:]
    vim.current.buffer[0] = 'MESSAGES IN TOPIC "%s"' % topic_name 
    vim.current.buffer.append(79 * "-")
    for message in messages:
        body = message.get("message").encode('utf-8')
        user = message.get("user").get("username").encode("utf-8").replace("\n", " ")
        date_created = datetime.datetime.fromtimestamp(message.get("date_created")).strftime("%a %b %d %H:%M:%S %Y")
        stars = message.get("stars")
        message_id = message.get("id").encode("utf-8")
        vim.current.buffer.append(body)
        vim.current.buffer.append("%s | %s | %s" % (user, date_created, ", ".join(["★" + star.get("user").get("username").encode("utf-8") for star in stars])))
        vim.current.buffer.append(79 * "-")
        vim.command("map <buffer> <CR> <Esc>:call ConvoreMessagesList()<CR>")
EOF
endfunction

command! -nargs=0 Convore call ConvoreGroupsList()
