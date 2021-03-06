# borrowed from stdenv.setup
######################################################################
# Textual substitution functions.


substitute() {
    local input="$1"
    local output="$2"

    if [ ! -f "$input" ]; then
      echo "substitute(): file '$input' does not exist"
      return 1
    fi

    local -a params=("$@")

    local n p pattern replacement varName content

    # a slightly hacky way to keep newline at the end
    content="$(cat "$input"; printf "%s" X)"
    content="${content%X}"

    for ((n = 2; n < ${#params[*]}; n += 1)); do
        p="${params[$n]}"

        if [ "$p" = --replace ]; then
            pattern="${params[$((n + 1))]}"
            replacement="${params[$((n + 2))]}"
            n=$((n + 2))
        fi

        if [ "$p" = --subst-var ]; then
            varName="${params[$((n + 1))]}"
            n=$((n + 1))
            # check if the used nix attribute name is a valid bash name
            if ! [[ "$varName" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                echo "WARNING: substitution variables should be valid bash names,"
                echo "  \"$varName\" isn't and therefore was skipped; it might be caused"
                echo "  by multi-line phases in variables - see #14907 for details."
                continue
            fi
            pattern="@$varName@"
            replacement="${!varName}"
        fi

        if [ "$p" = --subst-var-by ]; then
            pattern="@${params[$((n + 1))]}@"
            replacement="${params[$((n + 2))]}"
            n=$((n + 2))
        fi

        content="${content//"$pattern"/$replacement}"
    done

    if [ -e "$output" ]; then chmod +w "$output"; fi
    printf "%s" "$content" > "$output"
}


substituteInPlace() {
    local fileName="$1"
    shift
    substitute "$fileName" "$fileName" "$@"
}


# Substitute all environment variables that do not start with an upper-case
# character or underscore. Note: other names that aren't bash-valid
# will cause an error during `substitute --subst-var`.
substituteAll() {
    local input="$1"
    local output="$2"
    local -a args=()

    # Select all environment variables that start with a lowercase character.
    for varName in $(env | sed -e $'s/^\([a-z][^= \t]*\)=.*/\\1/; t \n d'); do
        if [ "$NIX_DEBUG" = "1" ]; then
            echo "@${varName}@ -> '${!varName}'"
        fi
        args+=("--subst-var" "$varName")
    done

    substitute "$input" "$output" "${args[@]}"
}


substituteAllInPlace() {
    local fileName="$1"
    shift
    substituteAll "$fileName" "$fileName" "$@"
}
###########################################################################3
