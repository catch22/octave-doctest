%% -*- texinfo -*-
%% @defun test_all ()
%% tests
%%
%% @example
%% 42
%% @result{} ans =  42
%% @end example
%%
%% Note its not possible to call doctest from a doctest [1].
%% Instead, we use octave BIST mechanism.
%%
%% [1] https://github.com/catch22/octave-doctest/issues/184
%%
%% @end defun

function test_all()

end

%!test
%! [numpass, numtests, ~] = doctest ('test_octfile_single_fcn');
%! assert (numtests, 2)
%! assert (numpass, 2)

%!test
%! % different behaviour with or without extension
%! [dir, ~, ~] = fileparts (which ('test_octfile_multi.oct'));
%! autoload ('test_subfcn1', fullfile (dir, 'test_octfile_multi.oct'));
%! [numpass, numtests, ~] = doctest ('test_octfile_multi');
%! assert (numtests, 1)
%! assert (numpass, 1)
%! [numpass, numtests, ~] = doctest ('test_octfile_multi.oct');
%! assert (numtests, 4)
%! assert (numpass, 4)
