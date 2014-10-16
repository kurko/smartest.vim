" This file uses ideas from Gary Bernhardt for caching the latest test file,
" but adds a lot of other goodies.
"
" Some mappings I recommend:
"
" map <leader>t :call RunTestFile()<cr>
" map <leader>r :call RunNearestTest()<cr>
"

" RunTestFile()
"
" Runs all tests in the current test file.
"
" If the current file is a test file, it caches its path and runs the tests.
" If the current file is NOT a test file, it runs the last cached test path.
" This way, you don't need to keep the test file opened.
"
" Some of the strings we use to define if it's a test file:
"
"   \(.feature\|_spec.rb\|_test.rb\|_test.js\|_spec.js\)
"
function! RunTestFile(...)
  if a:0
    let command_suffix = a:1
  else
    let command_suffix = ""
  endif

  " Run the tests for the previously-marked file.
  let in_test_file = match(expand("%"), '\(.feature\|_spec.rb\|_test.rb\|_test.js\|_spec.js\)')

  if in_test_file >= 0
    call SetTestFile(command_suffix)
  elseif !exists("t:grb_test_file")
    :echo "Vim: I don't know what file to test :("
    return
  end

  call RunTests(t:grb_test_file . t:grb_test_line)
endfunction

" RunNearestTest()
"
" Same as RunTestFile(), except that it'll append the current line number to
" the path, so that you can run a single test.
"
" For example, in RSpec, `rspec test_path:12` will run only the spec under
" line 12.
"
" We try to find the same for Minitest tests.
function! RunNearestTest()
  let spec_line_number = line('.')
  call RunTestFile(":" . spec_line_number)
endfunction

function! SetTestFile(...)
  " Set the spec file that tests will be run for.
  if a:0 && a:1 != ""
    let t:grb_test_line = a:1
  else
    let t:grb_test_line = ""
  endif

  let t:grb_test_file = @%
endfunction

function! RunTests(filename)

  " Save the current file and run tests for the given filename
  :w
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo
  :silent !echo;echo;echo;echo;echo;echo;echo;echo;echo;echo

  let isolated_spec = match(a:filename, ':\d\+$') > 0
  let cursor_line = substitute(matchstr(a:filename, ':\d\+$'), ":", "", "")

  " JAVASCRIPT
  if match(a:filename, '\(._test.js\|_spec.js\)') >= 0

    let filename_for_spec = substitute(a:filename, "spec/javascripts/", "", "")
    " Within a Ruby on Rails project
    "
    " Konacha
    if filereadable("Gemfile") && match(readfile("Gemfile"), "konacha") >= 0

      " Konacha with Zeus
      if glob(".zeus.sock") != ""
        :silent !echo "Konacha with zeus"
        exec ":!zeus rake konacha:run SPEC=" . filename_for_spec

      " Konacha with bundle exec
      else
        :silent !echo "Konacha with bundle exec"
        exec ":!bundle exec rake konacha:run SPEC=" . filename_for_spec
      endif

    " PhantomJS with NPM/Broccoli/Ember CLI
    "
    " If there's a tests/runner.js file
    elseif filereadable("tests/runner.js")
      call RunJsWithPhantomJs()

    " Everything else (QUnit)
    else
      "Rake
      :silent !echo "I don't know how to run these JS tests :["
    endif

  " RUBY
  elseif match(a:filename, '\(._test.rb\|_spec.rb\)') >= 0

    let filename_without_line_number = substitute(a:filename, ':\d\+$', '', '')

    " Minitest?
    if match(a:filename, '\(_test.rb\)') != -1

      let ruby_command = ":!ruby -I"
      let dependencies_path = "lib/"
      let rails_app = ""
      let rails_framework = ""

      " Rails framework codebase itself?
      "
      " Tests in Rails have different dependencies that we have to check
      if (globpath(".", "rails.gemspec") == "" ) == 0
        let rails_framework = substitute(a:filename, '/test/.*', '', '')
        let dependencies_path = rails_framework . "/lib:" . rails_framework . "/test"
      elseif match(readfile("Gemfile.lock"), "railties") >= 0
        let rails_app = substitute(a:filename, '/test/.*', '', '')
      endif

      " Running isolated test
      "
      " Let's find out what's the current test
      let test_method = ""
      if isolated_spec > 0
        let current_line = cursor_line
        while current_line > cursor_line - 50
          " matches something like 'def test_form_for', then removes 'def '
          let line_string = GetLineFromFile(current_line, filename_without_line_number)
          let test_method = matchstr(line_string, 'def test_.*')
          let test_method = substitute(test_method, 'def ', '', '')

          " If it finds a test method, gets out of the loop
          if test_method != ""
            break
          endif
          " We go backwards until we find `def test_.*`
          let current_line -= 1
        endwhile
      endif

      if rails_framework != ""
        :silent !echo "Testing rails/rails project"
      else if rails_app != ""
        :silent !echo "Testing rails app with minitest"
      endif

      if test_method != ""
        :exec ":silent !echo Running isolated test: " . test_method
      else
        :exec ":silent !echo Running all tests for " . filename_without_line_number
      endif

      let test_command = ""
      if rails_framework != ""
        let test_command = ruby_command
        let test_command = test_command . " " . dependencies_path
        let test_command = test_command . " " . filename_without_line_number
        if test_method != ""
          let test_command = test_command . " -n " . test_method
        endif
      elseif rails_app != ""
        let test_command = ":!spring rake test " . filename_without_line_number
      endif

      ":exec ":silent !echo ha " . test_command

      exec test_command

    " Bundler & RSpec
    elseif match(readfile(filename_without_line_number), '\("spec_helper\|''spec_helper\|capybara_helper\|acceptance_spec_helper\|acceptance_helper\)') >= 0

      " Spring (gem like Zeus, to make things faster)
      if match(system('spring status'), 'Spring is running') >= 0
        :silent !echo "Using Spring"
        exec ":!spring rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename

      " Zeus
      elseif glob(".zeus.sock") != "" && filereadable("Gemfile") >= 1
        :silent !echo "Using zeus"
        exec ":!zeus rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename

      " bundle exec
      elseif filereadable("Gemfile")
        :silent !echo "Using bundle exec"
        exec ":!bundle exec rspec --color --order random " . a:filename

      " pure rspec
      else
        :silent !echo "Using vanilla rspec"
        exec ":!rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename
      end

    " Everything else
    else
      :silent !echo "Using vanilla rspec outside Rails"
      exec ":!rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename
    end
  end
endfunction

function! GetLineFromFile(line, filename)
  return system('sed -n ' . a:line . 'p ' . a:filename)
endfunction

function! RunJsWithPhantomJs()
  " QUnit tests have a module() function. Here we figure that out and run only
  " the current file.
  let module_name = ""

  silent exec ":!echo Running specs with PhantomJS for current module"
  let l:command = "phantomjs test_build/tests/runner.js test_build/tests/index.html"

  " QUNIT?
  if filereadable("tests/index.html") && match(readfile("tests/index.html"), "qunit") >= 0
    let module_line_number = 1 + match(readfile(expand('%')), "module(")
    let module_line_string = GetLineFromFile(module_line_number, expand('%'))
    let module_name = substitute(module_line_string, "module('", '', '')
    let module_name = substitute(module_name, 'module("', '', '')
    let module_name = substitute(module_name, "', {", '', '')
    let module_name = substitute(module_name, '", {', '', '')
    let module_name = substitute(module_name, ' ', '%20', 'g')
    "let module_name = substitute(module_name, '/', '%2F', 'g')

    let l:command = l:command . "?module=" . module_name
  endif

  "if filereadable("Brocfile.js") && match(readfile("Brocfile.js"), "ember-cli") >= 0
  "else
  if filereadable("Brocfile.js") && filereadable("node_modules/broccoli-cli/bin/broccoli")

    let l:final_command = "rm -rf test_build && node_modules/broccoli-cli/bin/broccoli build test_build && " . l:command
  else
    silent exec ":!echo " . shellescape("Don't know how to run this :(", 1)
    return 0
  endif

  let message = "Running " . l:command
  silent exec ":!echo " . shellescape(l:command, 2)

  let l:result = system(l:final_command)

  if match(l:result, "\n$") < 0
    let l:result = l:result . "\n"
  endif
  let l:result_list = split(l:result, "\n")

  let l:index = 1
  for i in l:result_list
    if len(l:result_list) == l:index
      exec ":!echo " . shellescape(i, 1)
    else
      silent exec ":!echo " . shellescape(i, 1)
    endif
    let l:index += 1
  endfor
  redraw!
endfunction
