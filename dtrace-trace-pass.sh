sudo dtrace -F -n 'pid$target:pass::entry' -n 'pid$target:pass::return' -c "./pass hello"
