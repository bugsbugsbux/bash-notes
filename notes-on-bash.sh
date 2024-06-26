#!/bin/bash --norc

# TODO: line-continuation
# TODO: exporting
# TODO: job control: <https://www.gnu.org/software/bash/manual/html_node/Job-Control-Basics.html>
# TODO: shell settings, `set` `shopt`
# TODO: getopts
# TODO: expanding indirect array

# `#` as first character of a word (see below) comments rest of line.
# The first line of this file was a comment too, but is also a shebang, a unix
# convention, that specifies how to run the file, when executed as
# an executable file (`chmod u+x ./file; ./file`).

# based on the talk by James Panacciulli available at:
# <https://www.youtube.com/watch?v=BJ0uHhBkzOQ>

# Rule of bash: Better quote than be sorry!

# Terminology:
# - word: char-sequence considered a single unit
# - list: 1+ commands or pipelines
# - name: words matching ^[[:alpha:]_]+[[:alnum:]_]*$ but not just a single underscore
# - parameter: stores a value; see: variable
# - variable: named parameter, as opposed to numbered or special-char-addressed
# - attribute: meta info about a parameter influencing its behaviour, can be set with `declare`

# Basic syntax:
echo optional arguments     # `echo` prints the arguments and a final newline to the screen
echo                        # calls `echo` without arguments; this only prints a newline
printf '%s\n' a b c d e     # printf's first arg specifies how to combine the rest: each on own line
printf '%s\n' "a b" c 'd e' # quotes mark argument boundaries when surrounded by whitespace
printf '%s\n' not" 3"' args'
name=                       # set variable name to null (which is a valid value!)
name="my value"             # do NOT put spaces around `=`
printf '%s\n' $name         # expand=use variable; equivalent to `printf '%s\n' my value`
printf '%s\n' "$name"       # expansion in string; equivalent to `printf '%s\n' "my value"`
printf '%s\n' '$name'       # prevents expansion;  equivalent to `printf '%s\n' '$name'`

# Advanced topics on variables:
# - see also: arrays, associative arrays, scopes/namespaces
# - builtins `declare` and `local` create new variables with given attributes in respective scope
# - `printf -v name ...` assigns to the given name instead of printing to stdout
# - `declare -n pointer=target` creates a new pointer variable (has attribute `n`) which redirects
#    all actions to the target, thus assigning to a pointer modifies the target
# - `unset` removes the given variables, and their targets if they are pointers (has attribute `n`)
# - `unset -n pointer` removes a pointer but not it's target
# - `local -I name` creates a local copy of name from the outer scope
unset name pointer target
#
declare name=orig target=name               # not a real pointer because it doesn't have attribute n
printf -v "$target" '%s' "hello world"      # write to variable
echo "$target;$name;"
unset target                                # as this isn't a real pointer, only unsets `pointer`
echo "$target;$name;"
#
name=orig; declare -n pointer=name          # creates real pointer which behaves like the target
echo "$pointer;$name;"
pointer=new
echo "$pointer;$name;"
unset pointer                               # removes both: pointer and its target `name`
echo "$pointer;$name;"
#
name=orig; declare -n pointer=name
unset -n pointer                            # only removes pointer but not it's target
echo "$pointer;$name;"

# Types of commands (check with command `type`):
# - file
# - keyword
# - function
# - builtin
# - alias
type ls
type function
function greet { echo hello; } # or `greet() { echo hello;}`
type greet
type alias
alias hi=greet
type hi

# Getting help:
# - type: show type of command
# - help: info about *bash* builtins and keywords
# - apropos: search man-pages
# - man: open man-page of command; number as first arg selects man-section
# - info: open help pages in texinfo format; mainly used by gnu programs
type kill       # prints type and sometimes the definition
help kill       # only short info about builtins; see `man bash` for more
apropos kill
man kill        # type q to exit
man 2 kill      # type q to exit
info kill       # type q to exit
declare -p name # print definition of a variable (not function)
declare -f name # print definition of a function

# Using local definitions on remote:
# - this prepends "code" with the definitions of given variables and functions
# ssh remote "$(declare -p vars; declare -f funcs;) code"

# Accessing arguments (of current function or, when not in a function, of the script):
# - `set --` fakes which arguments the current script was called with
set -- a b c d e f "g h i" j k l
#
echo $#                 # get number of args: 2
echo "$1, $3"           # uses first and third arg
echo $10 ${10}          # nth arg >9 must be specified in braces
echo ">${100}<"         # missing args default to empty
printf '%s\n' "$*"      # `*` gives elements as a single string
printf '%s\n' "$@"      # `@` gives each element, preserving their boundaries when quoted...
printf '%s\n' $@        # ...but not when unquoted
printf '%s\n' '$@'      # obviously single quotes prevent the expansion entirely

# Exit/return status/code:
# Every command returns an exit code between (incl) 0 and 255 where:
# - 0: should indicate success
# - 1-255: should indicate different types of failures
# Last command's status is available as `$?`.
# The builtins `true` and `false` reutrn 0 and 1 respectively,
# builtin `:` does nothing and returns 0
true ; echo $?
false; echo $?
: ; echo $?

# Combining commands
echo hello ; echo world     # same as newline: one after another
echo hello & echo world     # execute simultaneously; only last stays in foreground
echo hello &                # run command in background
false && echo not happening # only execute last if previous succeeded (status 0)
true || echo not happening  # only execute last if previous failed (status not 0)
# - simple branching:
false && echo True || echo False # Note the order: `condition && when-true || when-false`
false || echo False && echo True # WRONG ORDER -> executes both "branches"
# - `wait` after backgrounded commands avoids receiving outputs at unexpected times:
(sleep 5; echo awaken)& echo hello       # quickly type:
sleep 5; echo interrupted                # now, compare to this:
(sleep 5; echo awaken)& echo hello ;wait # quickly try to type:
echo last

# Pipes and Redirections:
# - stdout, stderr, stdin are so called "file descriptors"
# - commands can write output to stdout and stderr
# - outputs of commands can be redirected to files or other file descriptors
# - to "pipe" one command into another means to connect the outputs of a command to another's stdin
# - some commands detect whether they run in a pipe and then behave differently
# - the rhs of a pipe is always a subshell (see below); thus it does not affect the environment
# - commands can take stdin from a file
# - to ignore an output it is the convention to redirect it to /dev/null
# - these examples require `cat` and `rev` which should be widely available:
echo hello > /tmp/demo  # redirects stdout to file (overrides it)
echo world >>/tmp/demo  # redirects stdout to file (appends to it)
cat < /tmp/demo         # read stdin from file
error 2>/tmp/demo       # redirects stderr to file (use `2>>` to append)
cat /tmp/demo
echo hello &>/tmp/demo  # redirects stdout and stderr to file (overrides it)
error &>>/tmp/demo      # redirects stdout and stderr to file (appends to it)
cat /tmp/demo
error 2>&1              # redirects stderr to stdout
echo hello | rev        # connects stdout of echo to stdin of rev
error | rev             # stderr still goes to screen and is not received by rev
echo hi 2>/tmp/demo >&2 # multiple redirections; stderr>file, stdout>stderr, somehow order matters
cat /tmp/demo
error 2>&1 | rev        # connects stdout to stdin and redirects stderr of `error` to its stdout
error |& rev            # equivalent
error 2>/dev/null       # convention for suppressing stderr; redirections don't change return status
echo $?
name=(); echo -e 'one\ntwo' | while read; do name+=("$REPLY"); done
printf '%s\n' "${name[@]}"  # unchanged due to subshell not influencing env
# instead do this:
while read; do name+=("$REPLY"); done < <(echo -e 'one\ntwo')
printf '%s\n' "${name[@]}"

# If-statements:
# - semicolons may be replaced by newlines
# - keywords may be place on their own lines
# - syntax:
#   `if COMMANDS; then COMMANDS; [ elif COMMANDS; then COMMANDS; ]... [ else COMMANDS; ] fi`
if false
then echo "if branch is required"
elif false
then echo "elif branch is optional"
else echo "else branch is optional"
fi

# Tests: use `help test` and `help [[`
# - `test expr` is `[ expr ]` and a builtin thus safe to use even when concerned about portability
# - `/bin/test` does the same as `test` but runs as system process
# - `[[ expr ]]` are keywords thus process expr differently:
#   + no word splitting during parameter expansion
#   + combine conditions with && and || which do not evaluate rhs if lhs suffices
#   + rhs of == and != is literal when quoted
#   + rhs of == and != is pattern when unquoted
#   + rhs of =~ is regex
test -n "not nothing"; echo $?
test -z "zero length"; echo $?
[[ bar == "baz" ]]; echo $?

# Pattern matching:
# - pattern matching works in
#   + path-expansions
#   + unquoted rhs of == and != in [[
#   + unquoted cases of case-statements
#   + some parameter-expansions
# - `*` matches any string including null
# - `?` matches any single char
# - patterns with alternatives:
#   + `[xyz]` matches x, y or z
#   + `[^xyz]` matches everything except x, y or z
#   + `[0-3a-c]` matches 0, 1, 2, 3, a, b or c
#   + `[[:digit:]]` matches the digits, for allowed classes see: `man 7 regex`
echo /*
[[ bar == ba[zr] ]]; echo $?

# Case-statements:
# cases are specified as
# - string or pattern
# - optionally more strings or patterns each separated with `|`
# - followed by `)`
# - the case-body, which may start immediately after `)`
# case-bodies end with
# - `;;` continues execution after the case-statement
# - `;&` executes next case-body regardless of whether it's case matches
# - `;;&` continues executing the next *matching* case
# the entire case statement can be written in one line without the need for a `;` after `in`
case word in
    'wor[dt]') echo literally 'word[dt]'
    ;;
    wor[dt]) echo either german or english for '"word"'
    ;;&
    word | wort)
        echo same but only executes if above match didn\'t terminate with ';;'
    ;&
    foobar) echo this case does not match
    ;;
    *) echo this case always matches -- but it it executed\?
    ;;
esac

# Brace expansions:
# - generate combinations and sequences
# - useful in for-loops (see below)
echo a{X,Y,Z}b
echo a{X,Y,Z} {X,Y,Z}b
echo a{X,}b a{,X}b
echo a{1..3}b a{X..Z}b a{x..z}b
echo a{0..10..2}
echo {a..z..2}
echo a{{1..3},{X..Z}}b
echo {1..5}{0,5}%
echo twice{,}

# Parameter expansion: `${` + name (+ operator + argument) + `}`
# - also work with array elements by appending index in brackets to name: `name[0]`
# - operators for handling unset (null is not unset) and empty parameters:
#   + `${name-fallback}`: if unset return "fallback"
#   + `${name=fallback}`: if unset return "fallback" and assign it to name
#   + `${name?errormsg}`: if unset throw error with message "errormsg"
#   + `${name+override}`: if name is set (including empty) return "override" value
# - these do the same but treat empty as unset:
#   + `${name:-fallback}`: if unset or empty return "fallback"
#   + `${name:=fallback}`: if unset or empty return "fallback" and assign it to name
#   + `${name:?errormsg}`: if unset or empty throw error with message "errormsg"
#   + `${name:+override}`: if name is set (unless empty) return "override" value
# - operators for string manipulation
#   + `${name:n}`:        rm first n characters
#   + `${name:n:m}`:      rm first n characters, then take next m
#   + `${name#pattern}`:  rm non-greedy pattern from start
#   + `${name##pattern}`: rm     greedy pattern from start
#   + `${name%pattern}`:  rm non-greedy pattern from end
#   + `${name%%pattern}`: rm     greedy pattern from end
#   + `${name/pattern/str}`:  replace first  match of greedy pattern with given str
#   + `${name//pattern/str}`: replace all  matches of greedy pattern with given str
#   + `${name/#pattern/str}`: replace greedy pattern which must be at start with given string
#   + `${name/%pattern/str}`: replace greedy pattern which must be at end with given string
foo=bar  ; echo "${foo-fallback}"
unset foo; echo "${foo-fallback}"
echo "${foo?not set}"   # prevents execution of echo
name=abcAbc; echo "${name:1}" "${name:0:2}"
echo "${name#*b}" "${name##*b}"
echo "${name%b*}" "${name%%b*}"
echo "${name/*b/.}" "${name/?b/.}" "${name//?b/.}"
echo "${name/#?b?/.}" "${name/%?b?/.}"
# - operations on variable names:
#   + `${!name}`: gives value of name contained by variable `name`
#   + `${!pre*}`: all names starting with "pre" as single string
#   + `${!pre@}`: all names starting with "pre" as array
foo=bar; bar=baz; echo "${!foo}"    # does not work with longer redirection chains
bar=; baz=; printf '%s\n' "${!ba*}"
bar=; baz=; printf '%s\n' "${!ba@}"

# Arrays, Parameter expansion continued:
# - there are two types of arrays:
#   + "indexed arrays"
#   + "associative arrays"
# - every variable can be considered an array
# - not specifying an index is the same as specifying index 0
# - indices are specified in brackets following the array's name: `name[index]`
# - parameter expansions allow specifying an index after the name: `${name[1]?missing element}`
# - as `unset name` removes a variable, `unset name[i]` removes an element i from an array;
#   this does not shift the remaining elements up or down, the index is simply missing

# "Indexed arrays", Arrays continued:
# - one of the 2 types of arrays
# - a sequence of elements, accessible via indices starting at 0
# - assigning to negative indices is invalid
# - negative indices access elements counting from the back
# - indices are specified in brackets and interpreted as arithmetic expressions
# - using array like normal variables accesses element at index 0
# - `declare -a name`: explicitly creates *indexed* array name
# - `name[0]=first`: implicitly makes name an indexed array with element at index 0 "first"
# - `name=(first second last)`: creates indexed array with 3 elements
# - `name=(zero [2]=two three [5]=five six)` is equivalent to
#   `name=([0]=zero [2]=two [3]=three [5]=five [6]=six)`
# - `+=` operator with string on rhs appends to the original value
# - `+=` operator with a literal array on rhs modifies the original array like so:
#   elements before the first use of an explicit index are appended
#   after the highest used index; then the explicitly and implicitly named elements
#   are modified which may override elements which were just appended
# - `${name[i]}`: (i-1)th element
# - `${name[*]}` or `${name[@]}`: all elements disregarding their boundaries
# - `"${name[*]}"`: all values in one string separated by "${IFS[0]}"
# - `"${name[@]}"`: all values as seperate elements
# - `"${!name[@]}"`: all keys as seperate elements
# - `"${#name[@]}"`: length
# - `"${name[@]:n:m}"`: (try to) get m elements starting from index n
#   n specifies an index; m is the amount of elements to get not index n+m which is relevant when
#   there are elements missing
unset name
name=(first 'second element' last)
printf '%s\n' "${name[*]}"
printf '%s\n' "${name[@]}"
printf '%s\n' ${name[@]}
echo keys: "${!name[*]}"
echo length: "${#name[@]}"
echo length of element 0: "${#name[0]}" or simply "${#name}"
unset name
name[0]=first
name[0+1]=last          # arithmetic when assigning
echo "${name[1]}"
echo "${name[2-1]}"     # arithmetic when referencing
echo "${name[-1]}"      # count from back
unset name
name=(zero [2]=two three [5]=five six)
echo keys: "${!name[*]}"
printf '%s\n' "${name[@]}"  # when retrieving all, missing elements do not show up *at all*
name+=(7 8 [5]=5 6 seven)   # first appends elements 7 and 8 then modifies indices 5-7
echo values: "${name[*]}"
echo "${name[@]:3:3}"       # gets elements at indices 3,5,6
echo "${name[@]:8:2}"       # gets <2 elements because there are not enough starting at index 8

# "Associative arrays":
# - one of the 2 types of arrays
# - a collection of key-value pairs
# - the order is not guaranteed
# - indices are specified in brackets and *not* interpreted as arithmetic expressions
# - `declare -A name`: (capital A!) explicitly creates an *associative* array
# - `name=(k1 v2 k2 v2)` is equivalent to
#   `name=([k1]=v1 [k2]=v2)`
# - `+=` operator with string on rhs appends to the original value
# - `+=` operator with a literal array on rhs modifies the original array
unset name
declare -A name=([foo]=fizz [bar]=buzz)
echo keys: "${!name[*]}"
echo foo is: "${name[foo]}"
name+=([bar]=baz [foobar]=fizzbuzz)
printf '%s\n' "${name[@]}"
declare -A name=(a x b y c z)
echo "keys: ${!name[*]}; values: ${name[*]}"

# Arithmetic expressions (hereafter abbreviated to aexpr):
# - indices of indexed arrays are interpreted as aexprs; see above
# - for loops of the form `for (( aexpr ; aexpr ; aexpr )) ; do ...` use aexprs; see below
# - `$((` + aexp + `))`: gives result
# -  `((` + aexp + `))`: gives truthiness, determined like so:
#   + true if comparison, (in)equality is true
#   + *true if* calculated number is *not 0*
# - `name++` or `name--`: inside aexpr inc-/decrements the value of name after evaluating the aexpr
# - `++name` or `--name`: like `name++` or `name--` but reassigns name *before* evaluating the aexpr
# - `++name`,`--name`,`name++` and `name--` initialize unset variables to 0
# - follows arithmetic operator precedence
# - floors floating point numbers!
# - parameter expansion is allowed inside aexprs
echo $(( 2+3*4 ))       # mathematical precedence
echo $(( (2+3)*4 ))     # use parens to influence order
echo $((10/0))          # division by zero error
echo $((10/3))          # does not do fractional values
echo $((2**3))          # power
echo $((5%2))           # modulo
name=10; echo $(($name/3))
if ((1>2 || 0**(10%2) )); then echo True; else echo False; fi
name=0; echo $((name++)); echo $name
name=0; echo $((--name)); echo $name

# Loops:
# - semicolons may be replaced by newlines
# - keywords may be place on their own lines
# - keyword `break` can be used to exit loops early
# - keyword `continue` can be used to abort the current iteration and continue with the next
# - syntax:
#   + `while COMMANDS; do COMMANDS-2; done`
#   + `until COMMANDS; do COMMANDS-2; done`
#   + `for NAME [in WORDS ... ] ; do COMMANDS; done`
#   + `for (( AEXPR ; AEXPR ; AEXPR )); do COMMANDS; done`
i=0; while read -p"in: "
do
    echo "out: $REPLY"
    if ((++i>=2)); then break; fi
done
i=-1; while ((++i < 5)); do echo $i; done
i=-1; until ((++i >= 5)); do echo $i; done
for i in {0..4}; do echo $i; done
for (( i=0; i<5; i++)); do echo $i; done
#   + `select NAME [in WORDS ... ;] do COMMANDS; done`
#     prints each word with it's index to stderr; then waits for choice on stdin
#     the given variable NAME is set to the corresponding word of a valid choice
#     the variable `REPLY` is set to the line read from stdin
#     after executing the body it prompts for new input unless `break` was encountered
#     user can exit the loop by hitting ctrl+c or ctrl+d
#     *try the example once with input `2` and once with `2 3`*
select choice in foo bar baz; do echo "$choice; $REPLY"; break; done
select choice in foo bar baz; do echo "$choice; $REPLY"; done

# Command groups:
# - commands may be grouped to redirect them at once
# - there are two types of such groups:
#   + subshells, denoted by `( list )`, create their own environment derived from the outside one.
#     This means they do not influence the surrounding environment.
#   + brace surrounded groups, which do not create their own environment and thus influence the
#     surrounding one. To differentiate them from brace expansions (see above), they must start
#     with whitespace after the opening `{` and end with a semicolon before the `}` if they do
#     not contain multiple commands and are one-liners.
name=outside
(
    echo inherits outside environment: $name
    name=inside
    echo redefined name: $name
)
echo "but does not influence the surrounding environment: $name"
{ name=inside; }
echo "brace surrounded groups do influence the environment: $name"
{
    echo "${name?undefined}"
    echo "${foobar?undefined}"
} 2>/dev/null           # throw away stderr output

# Subshell substitution, Process substitution:
# - to replace a subshell expression with it's output, prepending it with `$`
#   quote the substitution to receive a single argument, dont to split it into words
# - the subshell expression of a quoted subshell substitution does not need to escape quotes
# - to treat a subshell expression as a file, prepend it with `<` or `>`
# - `<()` is used when one wants to read stdout of the subshell as a file
# - `>()` is used when one wants to write to a file which shall be used as stdin of the subshell
echo today is "$(echo "now")"    # not the unescaped quotes in the quoted substitution
cat <(echo hello; echo world)    # `cat` expects a filename as argument
echo hello world > >(rev)
# `tee` writes stdin to the given filename and outputs it to stdout
echo hello | tee >(rev >/tmp/demo) | cat
cat /tmp/demo

# Functions, Compound expressions, Scopes/Namespaces:
# - compound expressions are: subshells, brace surrounded expressions, arithmetic expressions,
#   [[ expressions, loops and conditional
# - syntax:
#   + `function NAME COMPOUND` the name may be followed by `()`
#   + OR: `NAME () COMPOUND`
#   + redirections directly following a function definition become part of the definition
# - only subshells create a new scope/namespace, all other compound expressions use the surrounding
#   namespace except for:
#   + the argument-variables ($1, $2, ..., $*, $@, $#) which always reference the arguments of the
#     current function
#     Note: $0 does not hold the name of the current function!
#   + variables after being declared as local using the `local` builtin instead of `declare`
#     Note: `local` allows the same options as `declare`
# - `return` exits the current function with the given (or 0) exit code
# - a variable and a function with the same name can exist at the same time
declare name=outside
error123 () {
    echo not the function name: $0
    echo first arg: $1
    name=inside         # modifies outside name because {}-body shares surrounding namespace
    local name="lol"    # using `local` shadows the outside name
    echo $name
    return 123          # set return status and exit function
} >&2                   # redirect stdout to stderr
declare -f error123     # shows that the redirection is part of the definition
error123 message >/tmp/demo_stdout 2>/tmp/demo_stderr
echo $?                 # successfully failed with code 123
cat /tmp/demo_stdout    # empty since all output went to stderr
cat /tmp/demo_stderr    # contains even what originally went to stdout
echo $foo               # not available anymore
unset error123          # remove function
# using a subshell as body:
unset name; function f ( name="contained to subshell"; );
f; echo ${name-name not set}
# function names are not variable names:
declare name=variable; function name () { echo "i'm not a $1"; }
declare -p name
declare -f name
name $name
