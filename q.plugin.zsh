# Load the regex module for regex expressions
zmodload zsh/regex

# Integrate with zsh-syntax-highlighter
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main regexp)
ZSH_HIGHLIGHT_REGEXP+=('\bq.*\b' 'fg=green,bold')
ZSH_HIGHLIGHT_REGEXP+=('\bQ.*\b' 'fg=green,bold')
ZSH_HIGHLIGHT_REGEXP+=('\bU.*\b' 'fg=green,bold')

# Setup the Q_HELP var
read -d '' Q_HELP <<EOF
Usage: q[register] [args]
       Q[register] [command]
       U[register]

Setting Registers:
 Q[register]                     Set register [register] to current directory
 Q[register] [command]           Set register [register] to [command]

Unsetting Registers:
 U[register]                     Unset register [register]

Running Registers:
 q[register]                     Run command or cd to directory in register [register]
 q[register] [args]              Run command in register [register] with [args]
EOF

# Create the register dir, if needed
mkdir -p $HOME/.q

print-regs() {
    # If the dir is not empty, print out each register and it's contents
    if [[ ! -z `ls $HOME/.q` ]]; then
        echo "\nRegisters:"
        for reg in $HOME/.q/*; do
            echo -n " ${reg##*/}: "
            cat $reg
        done
    fi
}

q-accept-line() {
    if [[ "$BUFFER" =~ "^[QqU][a-zA-Z0-9]*" ]]; then
        # If the command already exists, prefer that
        if type "$MATCH" > /dev/null; then
            zle .accept-line
            return
        fi

        # Check if trying to set to an existing command
        if type "q${MATCH:1}" > /dev/null; then
            echo "\nSorry, \"q${MATCH:1}\" is already a command in your \$PATH! :("
            BUFFER=""
            zle .accept-line
            return
        fi

        Q_COMMAND=${MATCH:0:1}
        REG=${MATCH:1}
        ARGS=${MATCH:${#MATCH}}

        # If called without register, show help
        if [[ $REG == "" ]]; then
            echo "\nq - registers for zsh"
            echo "\n$Q_HELP"
            print-regs
            BUFFER=""
            zle .accept-line
            return
        fi

        # If setting a register
        if [[ "$Q_COMMAND" == "Q" ]]; then
            # If there's no argument
            if [[ "$ARG" == "" ]]; then
                # Set the register to the current directory
                echo "cd `pwd`" > "$HOME/.q/$REG"
                echo "\nRegister $REG set to `pwd`"
                BUFFER=""
            else
                # Otherwise, set the register to the given command
                echo $ARGS > "$HOME/.q/$REG"
                echo "\nRegister $REG set to $ARGS"
                BUFFER=""
            fi
        # If trying to call a register
        elif [[ "$Q_COMMAND" == "q" ]]; then
            # Check it exists
            if [[ -f "$HOME/.q/$REG" ]]; then
                BUFFER="`cat $HOME/.q/$REG`$ARGS"
            else
                echo "\nRegister $REG is unset."
                BUFFER=""
            fi
        # If unsetting a register
        else
            # Check it exists
            if [[ -f "$HOME/.q/$REG" ]]; then
                rm "$HOME/.q/$REG"
                echo "\nUnset register $REG."
            else
                echo "\nRegister $REG already unset!"
            fi
            BUFFER=""
        fi
    fi

    # Accept the line with the new BUFFER
    zle .accept-line
}

# Replace the accept-line event with our own
zle -N accept-line q-accept-line
