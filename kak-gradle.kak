try %{
    # Declare highlighters for the tasks buffer
    add-highlighter global/gradle_tasks_buffer group
    add-highlighter global/gradle_tasks_buffer/task regex "(^[a-zA-Z0-9]*)( - [^\n]*)" 0:string 1:type

	# Declare highlighters for the dependencies buffer
	add-highlighter global/gradle_dep_buffer group
    add-highlighter global/gradle_dep_buffer/category regex "(^[a-zA-Z0-9]*)( - [^\n]*)" 0:string 1:type
    add-highlighter global/gradle_dep_buffer/dependency regex "([+\\]---)( [^\n]*)" 0:keyword 1:string
    add-highlighter global/gradle_dep_buffer/symbol regex "(\|)" 0:string
    add-highlighter global/gradle_dep_buffer/no_deps regex "^No dependencies$" 0:keyword
    add-highlighter global/gradle_dep_buffer/legend regex "(\([*n]\))( [^\n]*)" 0:string 1:type
} catch %{
    echo -debug "kak-gradle: Can't declare highlighters for *gradle* buffer."
    echo -debug "            Detailed error: %val{error}"
}

# Enable the highlighters for the gradle-tasks filetype
hook -group gradle-tasks-syntax global WinSetOption filetype=gradle-tasks %{
    add-highlighter buffer/gradle_tasks_buffer ref gradle_tasks_buffer
    hook -always -once window WinSetOption filetype=.* %{
        remove-highlighter buffer/gradle_tasks_buffer
    }
}

# Enable the highlighters for the gradle-deps filetype
hook -group gradle-deps-syntax global WinSetOption filetype=gradle-deps %{
    add-highlighter buffer/gradle_dep_buffer ref gradle_dep_buffer
    hook -always -once window WinSetOption filetype=.* %{
        remove-highlighter buffer/gradle_dep_buffer
    }
}

define-command -docstring "Execute arbitrary gradle command" -params .. gradle %{
    evaluate-commands %sh{
        echo "terminal ./gradle_wrap.sh $@"
    }
}

define-command -docstring "Initialize gradle project" gradle-init %{
    gradle "init"
}

define-command -docstring "Generate gradle wrapper files" gradle-wrapper %{
    gradle "wrapper"
}

define-command -docstring "List subprojects" gradle-projects %{
    info -title "Subprojects" %sh{ gradle projects | grep -E "Root project[^\n]+|Project" }
}

define-command -docstring "List available gradle tasks" gradle-tasks %{
    evaluate-commands %sh{
        tmp=$(mktemp -d "${TMPDIR:-/tmp}/kak-gradle.XXXXXXXX")
        fifo=$tmp/fifo
        mkfifo ${fifo}
        # Run "gradle tasks" in the background and extract strictly the task names
        ( gradle tasks | grep '^[a-zA-Z0-9]* -' > ${fifo} 2>&1 & ) > /dev/null 2>&1 < /dev/null

        printf "%s\n" "edit! -fifo ${fifo} *gradle*
        	set-option buffer filetype gradle-tasks
        	hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -rf ${tmp} } }
        	map buffer normal '<ret>' ':<space>gradle-fifo-operate<ret>'"
    }
}


define-command -docstring "List project dependencies" gradle-dependencies %{
    evaluate-commands %sh{
        tmp=$(mktemp -d "${TMPDIR:-/tmp}/kak-gradle.XXXXXXXX")
        fifo=$tmp/fifo
        mkfifo ${fifo}
		# Run "gradle dependencies" in the background and extract the dependencies and "legend"
        (gradle dependencies | grep -E '^[a-zA-Z0-9]* -|[+\]--- |No dependencies|\([*n]\)|^$' > ${fifo} 2>&1 & ) > /dev/null 2>&1 < /dev/null

        printf "%s\n" "edit! -fifo ${fifo} *gradle*
        	set-option buffer filetype gradle-deps
        	hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -rf ${tmp} } }"
    }
}

define-command -hidden gradle-fifo-operate %{ evaluate-commands -save-regs t %{
    execute-keys -save-regs '' "ghw"
    set-register t %val{selection}
    evaluate-commands %sh{
        task="${kak_reg_t%:*}"
        echo "terminal ./gradle_wrap.sh $task"
    }
}}
