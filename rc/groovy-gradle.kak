hook global BufCreate .*\.gradle %{
    set-option buffer filetype gradle
}

hook global WinSetOption filetype=gradle %{
    require-module groovy_gradle

    #Remove trailing whitespaces on exiting insert mode
    hook window ModeChange pop:insert:.* -group gradle-trim-indent %{ try %{ execute-keys -draft <a-x>s^\h+$<ret>d } }
    #Indentation related hooks
    hook window InsertChar \n -group gradle-indent gradle-indent-newline
    hook window InsertChar \{ -group gradle-indent gradle-indent-opening-curlybrace
    hook window InsertChar \} -group gradle-indent gradle-indent-closing-curlybrace

    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window gradle-.+ }
}

provide-module groovy_gradle %{

    hook -group gradle-highlight global WinSetOption filetype=gradle %{
        add-highlighter window/gradle ref gradle
        hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/gradle }
    }

    add-highlighter shared/gradle regions
    add-highlighter shared/gradle/code default-region group
    add-highlighter shared/gradle/double_string region '"'   (?<!\\)(\\\\)*"  fill string
    add-highlighter shared/gradle/single_string region "'"   (?<!\\)(\\\\)*'  fill string
    add-highlighter shared/gradle/comment region /\* \*/ fill comment
    add-highlighter shared/gradle/inline_documentation region /// $ fill documentation
    add-highlighter shared/gradle/line_comment region // $ fill comment

    define-command -hidden gradle-indent-on-closing-curly-brace %[
        try %[ execute-keys -itersel -draft <a-h><a-k>^\h+\}$<ret>hms\A|.\z<ret>1<a-&> ]
    ]

    define-command -hidden gradle-indent-newline %~
        evaluate-commands -draft -itersel %=
            try %{ execute-keys -draft <semicolon>K<a-&> }
            try %[ execute-keys -draft k<a-x> <a-k> [{(]\h*$ <ret> j<a-gt> ]
            try %{ execute-keys -draft k<a-x> s \h+$ <ret>d }
        =
    ~

    define-command -hidden gradle-indent-opening-curlybrace %[
        try %[ execute-keys -draft -itersel h<a-F>)M <a-k> \A\(.*\)\h*\n\h*\{\z <ret> s \A|.\z <ret> 1<a-&> ]
    ]

    define-command -hidden gradle-indent-closing-curlybrace %[
        try %[ execute-keys -itersel -draft <a-h><a-k>^\h+\}$<ret>hms\A|.\z<ret>1<a-&> ]
    ]
}
