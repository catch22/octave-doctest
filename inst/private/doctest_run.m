function results = doctest_run(docstring, defaults)
%DOCTEST_RUN - used internally by doctest
%
% Usage:
%   doctest_run(docstring)
%       Runs all the examples in the given docstring and returns a
%       structure with the results from running.
%
% The return value is a structure with the following fields:
%
% results.source:   the source code that was run
% results.want:     the desired output
% results.got:      the output that was recieved
% results.passed:   whether .want and .got match each other according to
%       doctest_compare.
%

% extract tests from docstring
TEST_RE = [                               % loosely based on Python 2.6 doctest.py, line 510
    '(?m)(?-s)'                          ... % options
    '(?:^ *>> )'                         ... % ">> "
    '(.*(?:\n *\.\. .*)*)\n'             ... % rest of line + ".. " lines
    '((?:(?:^ *$\n)?(?!\s*>>).*\S.*\n)*)'];  % the output

tests = [];
test_matches = regexp(docstring, TEST_RE, 'tokens');
for i=1:length(test_matches)
  % each block should be split into source and desired output
  source = test_matches{i}{1};
  tests(i).want = test_matches{i}{2};

  % replace initial '..' by '  ' in subsequent lines
  lines = strsplit(source, '\n');
  source = lines{1};
  for j = 2:length(lines)
    T = regexp(lines{j}, '^\s*(\.\.)(.*)$', 'tokens');
    assert(length(T) == 1);
    T = T{1};
    assert(length(T) == 2);
    source = sprintf('%s\n   %s', source, T{2});
  end
  tests(i).source = source;

  % set default options
  tests(i).normalize_whitespace = defaults.normalize_whitespace;
  tests(i).ellipsis = defaults.ellipsis;
  tests(i).is_texinfo = defaults.is_texinfo;
  tests(i).is_diary = defaults.is_diary;
  tests(i).skip = {};
  tests(i).xfail = {};

  % find and process directives
  re = [ ...
    '[#%]\s*doctest:\s+' ... % e.g., "# doctest: "
    '([\+\-]\w+)'        ... % token for cmd, e.g., "+XSKIP_IF"
    '(\s*\('             ... % token for code, starting with "("
      '[^#%\n]+'         ... % no newlines, no comments in code
    '\))?'];                 % ")" of code, at most one code arg
  directive_matches = regexp(tests(i).source, re, 'tokens');
  for j = 1:length(directive_matches)
    directive = directive_matches{j}{1};
    if (strcmp('+SKIP_IF', directive) || strcmp('+SKIP_UNLESS', directive) || strcmp('+XFAIL_IF', directive) || strcmp('+XFAIL_UNLESS', directive))
      if length(directive_matches{j}) == 2
        condition = directive_matches{j}{2};
      else
        error('doctest: syntax error, expected %s(varname)', directive);
      end
    end

    if strcmp('NORMALIZE_WHITESPACE', directive(2:end))
      tests(i).normalize_whitespace = strcmp(directive(1), '+');
    elseif strcmp('ELLIPSIS', directive(2:end))
      tests(i).ellipsis = strcmp(directive(1), '+');
    elseif strcmp('+SKIP', directive)
      tests(i).skip{end + 1} = 'true';
    elseif strcmp('+SKIP_IF', directive)
      tests(i).skip{end + 1} = condition;
    elseif strcmp('+SKIP_UNLESS', directive)
      tests(i).skip{end + 1} = sprintf('~(%s)', condition);
    elseif strcmp('+XFAIL', directive)
      tests(i).xfail{end + 1} = 'true';
    elseif strcmp('+XFAIL_IF', directive)
      tests(i).xfail{end + 1} = condition;
    elseif strcmp('+XFAIL_UNLESS', directive)
      tests(i).xfail{end + 1} = sprintf('~(%s)', condition);
    else
      warning('Doctest:unexpected-directive', 'doctest: ignoring unexpected directive %s', directive);
    end
  end
end

% run tests in a local namespace
results = DOCTEST__run_impl(tests);

end


% given a cell array of conditions (represented as strings to be eval'ed),
% return the string that corresponds to their logical "or".
function result = DOCTEST__join_conditions(conditions)
  if isempty(conditions)
    result = 'false';
  else
    result = strcat('(', strjoin(conditions, ') || ('), ')');
  end
end

% the following function is used to evaluate all lines of code in same
% namespace (the one of this invocation of DOCTEST__run_impl)
function DOCTEST__results = DOCTEST__run_impl(DOCTEST__tests)

% do not split long rows (TODO: how to do this on MATLAB?)
if is_octave()
  split_long_rows(0, 'local')
end

% define test-global constants
DOCTEST_OCTAVE = is_octave();
DOCTEST_MATLAB = ~DOCTEST_OCTAVE;

% Octave has [no evalc command](https://savannah.gnu.org/patch/?8033)
DOCTEST__has_builtin_evalc = exist('evalc', 'builtin');

DOCTEST__results = [];
for DOCTEST__i = 1:numel(DOCTEST__tests)
  DOCTEST__result = DOCTEST__tests(DOCTEST__i);

  % determine whether test should be skipped
  % (careful about Octave bug #46397 to not change the current value of “ans”)
  eval (strcat ('DOCTEST__result.skip = ', ...
                 DOCTEST__join_conditions (DOCTEST__result.skip), ...
                ';'));
  if (DOCTEST__result.skip)
     continue
  end

  % determine whether test is expected to fail
  % (careful about Octave bug #46397 to not change the current value of “ans”)
  eval (strcat ('DOCTEST__result.xfail = ', ...
                 DOCTEST__join_conditions (DOCTEST__result.xfail), ...
                ';'));

  % evaluate input (structure adapted from a StackOverflow answer by user Amro, see http://stackoverflow.com/questions/3283586 and http://stackoverflow.com/users/97160/amro)
  try
    if (DOCTEST__has_builtin_evalc)
      DOCTEST__result.got = evalc(DOCTEST__result.source);
    else
      DOCTEST__result.got = doctest_evalc(DOCTEST__result.source);
    end
  catch DOCTEST__exception
    DOCTEST__result.got = DOCTEST__format_exception(DOCTEST__exception);
  end

  % determine if test has passed
  DOCTEST__result.passed = doctest_compare(DOCTEST__result.want, DOCTEST__result.got, DOCTEST__result.normalize_whitespace, DOCTEST__result.ellipsis);
  if DOCTEST__result.xfail
    DOCTEST__result.passed = ~DOCTEST__result.passed;
  end

  DOCTEST__results = [DOCTEST__results; DOCTEST__result];
end

end


function formatted = DOCTEST__format_exception(ex)

  if is_octave()
    formatted = ['??? ' ex.message];
    return
  end

  if strcmp(ex.stack(1).name, 'DOCTEST__run_impl')
    % we don't want the report, we just want the message
    % otherwise it'll talk about evalc, which is not what the user got on
    % the command line.
    formatted = ['??? ' ex.message];
  else
    formatted = ['??? ' ex.getReport('basic')];
  end
end
