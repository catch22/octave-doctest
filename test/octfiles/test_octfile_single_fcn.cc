#include <octave/oct.h>

DEFUN_DLD (test_octfile_single_fcn, args, ,
           "-*- texinfo -*-\n\
@deftypefn  {} {} test_octfile_single_fcn ()\n\
Testing\n\
\n\
@example\n\
b = 42\n\
@result{} b = 42\n\
b = b + 1\n\
@result{} b = 43\n\
@end example\n\
@end deftypefn")
{
  return ovl (0);
}
