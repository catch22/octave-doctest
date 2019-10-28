#include <octave/oct.h>

DEFUN_DLD (test_octfile_multi, args, ,
           "-*- texinfo -*-\n\
@deftypefn  {} {} test_octfile_multi ()\n\
Testing\n\
\n\
@example\n\
a = 42\n\
@result{} a = 42\n\
@end example\n\
@end deftypefn")
{
  return ovl (0);
}

DEFUN_DLD (test_subfcn1, args, ,
           "-*- texinfo -*-\n\
@deftypefn  {} {} test_subfcn1 ()\n\
Testing\n\
\n\
@example\n\
a = 43\n\
@result{} a = 43\n\
@end example\n\
@end deftypefn")
{
  return ovl (0);
}

DEFUN_DLD (test_subfcn2, args, ,
           "-*- texinfo -*-\n\
@deftypefn  {} {} test_subfcn2 ()\n\
Testing\n\
\n\
@example\n\
a = 44\n\
@result{} a = 44\n\
a = a + 1\n\
@result{} a = 45\n\
@end example\n\
@end deftypefn")
{
  return ovl (0);
}
