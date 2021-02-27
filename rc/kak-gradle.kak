decl -hidden str gradle_wrap %sh{ printf "%s/../src/%s" "${kak_source%/*}" "gradle_wrap.sh" }
decl -hidden str gradlew_wrap %sh{ printf "%s/../src/%s" "${kak_source%/*}" "gradlew_wrap.sh" }

decl -hidden str gradle_root_dir ""

decl -docstring "Determines whether to use the project's gradle wrapper or the systemwide gradle installation" bool gradle_use_gradlew false

decl -hidden str gradle_command "gradle"

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

define-command -hidden gradle-root-dir %{
    evaluate-commands %sh{
        cur_dir=$(pwd)
        out=""

        # Scour the filesystem, looking for a build.gradle file
        while [ $cur_dir != "/" ]
        do
            out=$(ls | grep "build.gradle")
            if [ "$out" = *"build.gradle"* ]; then
                break
            fi
            cd ..
            cur_dir=$(pwd)
        done

        # If we found a build.gradle file, then we found the gradle root directory
        # Otherwise, we aren't in a gradle project.
        if [ "$out" == *"build.gradle"* ]; then
            printf "set-option global gradle_root_dir %s\n" "$cur_dir"
        else
            echo "set-option global gradle_root_dir ''"
        fi
    }
}

define-command -docstring "Execute arbitrary gradle command" -params .. gradle %{
    evaluate-commands %sh{
        # If we haven't populated the gradle_root_dir option yet, then do so
        if [ "$kak_opt_gradle_root_dir" == '' ]; then
            echo "gradle-root-dir"
        fi
        # Determine if we need to use the gradle wrapper, or use the systemwide gradle command
        if [ "$kak_opt_gradle_use_gradlew" = "true" ]; then
            echo "terminal ${kak_opt_gradlew_wrap} $kak_opt_gradle_root_dir $@"
        else
            echo "terminal ${kak_opt_gradle_wrap} $@"
        fi
    }
}

define-command -docstring "Initialize gradle project" gradle-init %{
    gradle "init"
}

define-command -docstring "Generate gradle wrapper files" -params .. gradle-wrapper %{
    gradle "wrapper" %arg{@}
}

define-command -docstring "List subprojects" gradle-projects %{
    evaluate-commands %sh{
        # If we haven't populated the gradle_root_dir option yet, then do so
        if [ "$kak_opt_gradle_root_dir" == '' ]; then
            echo "gradle-root-dir"
        fi
        # Determine if we need to use the gradle wrapper, or use the systemwide gradle command
        if [ "$kak_opt_gradle_use_gradlew" = "true" ]; then
            echo "set-option global gradle_command $kak_opt_gradle_root_dir/gradlew"
        else
            echo "set-option global gradle_command gradle"
        fi
    }
    info -title "Subprojects" %sh{ $gradle_command projects | grep -E "Root project[^\n]+|Project" }
}

define-command -docstring "List available gradle tasks" gradle-tasks %{
    evaluate-commands %sh{
        # If we haven't populated the gradle_root_dir option yet, then do so
        if [ "$kak_opt_gradle_root_dir" == '' ]; then
            echo "gradle-root-dir"
        fi
        # Determine if we need to use the gradle wrapper, or use the systemwide gradle command
        if [ "$kak_opt_gradle_use_gradlew" = "true" ]; then
            echo "set-option global gradle_command $kak_opt_gradle_root_dir/gradlew"
        else
            echo "set-option global gradle_command gradle"
        fi
        
        tmp=$(mktemp -d "${TMPDIR:-/tmp}/kak-gradle.XXXXXXXX")
        fifo=$tmp/fifo
        mkfifo ${fifo}
        # Run "gradle tasks" in the background and extract strictly the task names
        ( $kak_opt_gradle_command tasks | grep '^[a-zA-Z0-9]* -' > ${fifo} 2>&1 & ) > /dev/null 2>&1 < /dev/null

        printf "%s\n" "edit! -fifo ${fifo} *gradle*
            set-option buffer filetype gradle-tasks
            hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -rf ${tmp} } }
            map buffer normal '<ret>' ':<space>gradle-fifo-operate<ret>'"
    }
}


define-command -docstring "List project dependencies" gradle-dependencies %{
    evaluate-commands %sh{
        # If we haven't populated the gradle_root_dir option yet, then do so
        if [ "$kak_opt_gradle_root_dir" == '' ]; then
            echo "gradle-root-dir"
        fi
        # Determine if we need to use the gradle wrapper, or use the systemwide gradle command
        if [ "$kak_opt_gradle_use_gradlew" = "true" ]; then
            echo "set-option global gradle_command $kak_opt_gradle_root_dir/gradlew"
        else
            echo "set-option global gradle_command gradle"
        fi

        tmp=$(mktemp -d "${TMPDIR:-/tmp}/kak-gradle.XXXXXXXX")
        fifo=$tmp/fifo
        mkfifo ${fifo}
        # Run "gradle dependencies" in the background and extract the dependencies and "legend"
        ( $kak_opt_gradle_command dependencies | grep -E '^[a-zA-Z0-9]* -|[+\]--- |No dependencies|\([*n]\)|^$' > ${fifo} 2>&1 & ) > /dev/null 2>&1 < /dev/null

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
        echo "terminal ${kak_opt_gradle_wrap} $task"
    }
}}
