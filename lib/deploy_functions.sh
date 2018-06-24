#!/bin/bash

dpath=$(readlink -f "$BASH_SOURCE")
dpath=${dpath%/*}
#*/

M_ROOT=$(readlink -f "$dpath/..")

source "$M_ROOT/conf/mon.conf"

[ -z "$LOG" ] && LOG="$M_ROOT/logs/deploy.log"

propagate() {
  # propagate variable foo=bar
  # separate multiple variables with space or comma or both
  local propagated=$1
  shift
  case propagated in
  variable|var)
    [ -z "$CURRTASKDIR" ] && echo "CURRTASKDIR is not defined" && return 1
    echo -e "$@" | tr ' ' '\n' | tr ',' '\n' | grep -v '^$' >> "$CURRTASKDIR/prop.var"
    ;;
  *)
    echo "Unknown expression: propagate $propagated"
    return 1
    ;;
  esac
}

store_vars() {
  [ -n "$verbose" ] && echo "Sourcing $1"
  for LINE in `cat "$1" | grep -vE "^[[:space:]]*$|^[[:space:]]*#"` ; do
    # to respect environment variables and variables passed from command line
    pvar=`expr "$LINE" : '[[:space:]]*\([a-zA-Z0-9_]*\)=.*$'`
    if [ -n "$pvar" ]; then
      pval="`eval echo "\\$$pvar"`"
      if [ -n "$pval" ]; then
        [ `expr "$pval" : "[0-9]*$"` -eq 0 ] && echo "${pvar}=\"`eval echo "\\$$pvar"`\"" >> "$2" && continue || echo "${pvar}=`eval echo "\\$$pvar"`" >> "$2" && continue
      fi
    fi
    
    $debug && echo "  == $LINE"
    ELINE=$(echo "$LINE" | sed 's|\\"|\\\\"|g;s|"|\\\"|g;s|`|\\\`|g;s_|_\|_g')
    $debug && echo "  << $ELINE"
    # This conditional evaluation below is a workaround for hard nuts like pipes
    # inside sub-shells. More complex constructs involving both sub-shell and 
    # non-sub-shell expression in a single line both with pipes will probably 
    # not work. Just avoid such things.
    eval "$LINE" 2>/dev/null
    eval $(eval "echo \"$LINE\"") 2>/dev/null
    if [ $? -eq 0 ]; then
      $debug && echo "evaluating plain line"
      eval "echo \"$LINE\"" >> "$2"
    else
      eval "$ELINE" 2>/dev/null
      eval $(eval "echo \"$ELINE\"") 2>/dev/null
      if [ $? -eq 0 ]; then
        $debug && echo "evaluating converted line"
        eval "echo \"$ELINE\"" >> "$2"
      else
        echo -e "ERROR: both plain and converted lines evaluation failed for this line:\n\n$LINE\n\n"
        exit 1
      fi
    fi
    $debug && echo "  >> `tail -1 "$2"`" || true
  done
}

ensure() {
  # ensure variable foo, bar
  local ensured=$1
  shift
  case ensured in
  variable|variables|var)
    for v in `echo -e "$@" | tr ' ' '\n' | tr ',' '\n' | grep -v '^$'`  ; do
      if [ -z "`eval \$$v`" ]; then
        echo "Variable $v is not defined!"
        return 1
      fi
    done
    ;;
  *)
    echo "Unknown expression: ensure $ensured"
    return 1
    ;;
  esac
  
  
  
}
