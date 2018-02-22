sudo dtrace -n 'pid$target::*strcmp:entry{trace(copyinstr(arg0)); trace(copyinstr(arg1))}' -c "./pass hello"
