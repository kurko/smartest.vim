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
  let in_test_file = match(expand("%"), '\(.feature\|_spec.rb\|_test.rb\|_test.js\|_spec.js\|_test.exs\|_test.ex\|Spec.scala\|Test.scala\|Test.java\)')

  if in_test_file >= 0
    call SetTestFile(command_suffix)
  elseif !exists("g:grb_test_file")
    :echo "Vim: I don't know what file to test :("
    return
  end

  call RunTests(g:grb_test_file . g:grb_test_line)
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
    let g:grb_test_line = a:1
  else
    let g:grb_test_line = ""
  endif

  let g:grb_test_file = @%
endfunction

function! RunTests(filename)

  :w
  " Save the current file and run tests for the given filename
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

  let smartest_test_description = ""
  let smartest_test_context = ""
  let smartest_test_command = ""

  " JAVASCRIPT
  if match(a:filename, '\(._test.js\|_spec.js\)') >= 0
    let smartest_test_context = "javascript"

    let filename_for_spec = substitute(a:filename, "spec/javascripts/", "", "")
    " Within a Ruby on Rails project
    "
    " Konacha
    if filereadable("Gemfile") && match(readfile("Gemfile"), "konacha") >= 0

      " Konacha with Zeus
      if glob(".zeus.sock") != ""
        let smartest_test_description = "Konacha with zeus"
        let test_command_from_file = "zeus rake konacha:run SPEC=" . filename_for_spec

      " Konacha with bundle exec
      else
        let smartest_test_description = "Konacha with bundle exec"
        let test_command_from_file = "bundle exec rake konacha:run SPEC=" . filename_for_spec
      endif

    " PhantomJS with NPM/Broccoli/Ember CLI
    "
    " If there's a tests/runner.js file
    elseif filereadable("tests/runner.js")
      call RunJsWithPhantomJs()

    " Everything else (QUnit)
    else
      "Rake
      let smartest_test_description = "I don't know how to run these JS tests :["
    endif

  " CUCUMBER
  elseif match(a:filename, '\(.feature\)') >= 0
    let filename_without_line_number = substitute(a:filename, ':\d\+$', '', '')
    let smartest_test_context = "cucumber"

    if filereadable("Gemfile")
      let smartest_test_description = "bundle exec cucumber " . a:filename
      let smartest_test_command = "bundle exec cucumber " . a:filename
    else
      let smartest_test_description = "cucumber " . a:filename
      let smartest_test_command = "cucumber " . a:filename
    endif

  " RUBY
  elseif match(a:filename, '\(._test.rb\|_spec.rb\)') >= 0
    let filename_without_line_number = substitute(a:filename, ':\d\+$', '', '')
    let smartest_test_context = "ruby"

    " Minitest?
    if match(a:filename, '\(_test.rb\)') != -1
      let ruby_command_with_bundler = ":!bundle exec ruby -I"
      let ruby_command = ":!ruby -I"
      let dependencies_path = "lib/:test/"
      let rails_app = ""
      let gem_development = ""
      let rails_framework = ""

      " Rails framework codebase itself?
      "
      " Tests in Rails have different dependencies that we have to check
      if (globpath(".", "rails.gemspec") == "" ) == 0
        let rails_framework = substitute(a:filename, '/test/.*', '', '')
        let dependencies_path = rails_framework . "/lib:" . rails_framework . "/test"
      elseif match(readfile("Gemfile.lock"), "railties") >= 0

        if (globpath(".", "app") == "" ) == 0
          let rails_app = substitute(a:filename, '/test/.*', '', '')
        else
          let gem_development = substitute(a:filename, '/test/.*', '', '')
        endif
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
          if test_method == ""
            let test_method = matchstr(line_string, "it ['\"].*['\"] do")
            let test_method = substitute(test_method, 'it "', '', '')
            let test_method = substitute(test_method, '" do', '', '')
            let test_method = substitute(test_method, "it '", '', '')
            let test_method = substitute(test_method, "' do", '', '')

            if test_method != ""
              let test_method = substitute(test_method, " ", ".\+", "g")
              let test_method = substitute(test_method, "\\$", ".", "g")
              let test_method = "/" . test_method . "$/"
            endif
          endif

          " If it finds a test method, gets out of the loop
          if test_method != ""
            break
          endif
          " We go backwards until we find `def test_.*`
          let current_line -= 1
        endwhile
      endif

      if rails_framework != ""
        let smartest_test_description = "Testing rails/rails project"
      elseif rails_app != ""
        let smartest_test_description = "Testing rails app with minitest"
      else
        let smartest_test_description = "Testing plain Ruby app"
      endif

      if test_method != ""
        let smartest_test_description = "\nRunning isolated test: " . test_method
      else
        let smartest_test_description = "\nRunning all tests for " . filename_without_line_number
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

        " It's a Rails app and we want to run an isolated test
        if test_method != ""
          let test_command = ":!spring rake test " . filename_without_line_number . " " . test_method
        else
          let test_command = ":!spring rake test " . filename_without_line_number
        endif
      elseif gem_development != ""
        let test_command = ":!rake TEST=" . filename_without_line_number
      else
        let test_command = ruby_command_with_bundler
        let test_command = test_command . " " . dependencies_path
        let test_command = test_command . " " . filename_without_line_number
        if test_method != ""
          let test_command = test_command . " -n " . test_method
        endif
      endif

      " exec test_command

    " Bundler & RSpec
    " elseif match(readfile(filename_without_line_number), '\("spec_helper\|''spec_helper\|rails_helper\|capybara_helper\|acceptance_spec_helper\|acceptance_helper\)') >= 0
    elseif match(filename_without_line_number, '\(_spec.rb\)') >= 0
      let smartest_test_context = "ruby"

      " Zeus
      if glob(".zeus.sock") != "" && filereadable("Gemfile") >= 1
        let smartest_test_description = "Using zeus"
        let test_command_from_file = "zeus rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename

      " Spring (gem like Zeus, to make things faster)
      elseif match(system('spring status'), 'Spring is running') >= 0
        let smartest_test_description = "Using Spring"
        let test_command_from_file = "spring rspec --color --format progress --no-drb --order random " . a:filename

      " Spring within bundler
      elseif match(system('bundle exec spring status'), 'Spring is running') >= 0
        let smartest_test_description = "Using Spring with bundler"
        let test_command_from_file = "bundle exec spring rspec --color --format progress --no-drb --order random " . a:filename

      " bundle exec
      elseif filereadable("Gemfile")
        let smartest_test_description = "Using bundle exec"
        let smartest_test_command = "bundle exec rspec --color --order random " . a:filename

      " pure rspec
      else
        let smartest_test_description = "Using vanilla rspec"
        let test_command_from_file = "rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename
      end

    " Everything else
    else
      let smartest_test_description = "Using vanilla rspec outside Rails"
      let test_command_from_file = "rspec -O ~/.rspec --color --format progress --no-drb --order random " . a:filename
    end
  " ELIXIR
  elseif match(a:filename, '\(._test.ex\|_test.exs\)') >= 0
    let smartest_test_context = "elixir"

    if match(a:filename, '\(._test.exs\)') >= 0
      " Mix
      let smartest_test_description = "Using ExUnit with Mix"
      let test_command_from_file = "mix test " . a:filename
    else
      " ExUnit
      let smartest_test_description = "Using ExUnit outside Mix"
      let test_command_from_file = "elixir " . a:filename
    end
  " SCALA
  elseif match(a:filename, '\(.Spec.scala\|Test.scala\)') >= 0
    let smartest_test_context = "scala"

    let smartest_test_description = "Using activator test-only option"
    let test_command_from_file = "activator 'testOnly *." . expand('%:t:r') . "'"

  " JAVA
  "
  " We don't run the test itself here, but log the file name and test
  elseif match(a:filename, '\(Test.java\)') >= 0
    let smartest_test_context = "java"

    let smartest_test_description = "Using Java context"

    "let test_class_name = ''
    "let file = readfile(expand("%:p"))
    "for line in file
    "  let matched_class_name = matchstr(line, 'public class \zs\([A-Za-z]*Test\)\ze.*')
    "  if(!empty(matched_class_name))
    "    let test_class_name = matched_class_name
    "  endif
    "endfor

    "echo "X" . test_class_name
    " let test_command_from_file = "-Dtest=" . expand('%:t:r') . "'"
    let class_name = "-Dtest=" . expand('%:t:r') . "'"
    let target_parameters = "-Dtest=" . expand('%:t:r') . "'"
  end


  " If there's any file .smartest.*, then we expect to only use those types of
  " files and we will show an error in case some is missing.
  if glob('.smartest.*') !=#""
    if filereadable(".smartest." . smartest_test_context)
      let test_command_from_file = readfile(".smartest." . smartest_test_context)[0]

      " Replaces $smartest_test_command in the file with whatever smartest figured out as
      " expected.
      let final_test_command = substitute(test_command_from_file, "$smartest_test_command", smartest_test_command, "")
      let final_test_command = substitute(final_test_command, "$filename", a:filename, "")

      silent exec ":!echo " . smartest_test_description
      " shellescape will write with quotes to stdout
      silent exec ":!echo Running: " . shellescape(final_test_command, 1)
      exec ":!" . final_test_command
    else
      echo "Don't know how to run tests. Define .smartest." . smartest_test_context
    endif
  else
    silent exec ":!echo " . smartest_test_description
    exec ":!" . smartest_test_command
  endif

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
