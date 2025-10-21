# .credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [
          # Common patterns
          ~r"/_build/",
          ~r"/deps/",
          ~r"/node_modules/",

          # Generated files
          ~r"/priv/static/",
          ~r"/priv/gettext/",

          # Mix tasks and test support files that might be noisy
          ~r"/test/support/factory.ex",
          ~r"/test/support/data_case.ex",
          ~r"/test/support/conn_case.ex",

          # Redis backend (deferred to future release)
          ~r"/lib/ash_phoenix_translations/redis_",
          ~r"/lib/mix/tasks/ash_phoenix_translations\.(import|export|sync|clear|info)\.redis\.ex",
          ~r"/lib/ash_phoenix_translations/calculations/redis_translation\.ex",

          # Redis tests
          ~r"/test/redis_",
          ~r"/test/calculations/redis_translation_test\.exs",
          ~r"/test/mix/redis_mix_tasks_test\.exs",

          # CSRF protection - uses nested modules within optional dependency check
          ~r"/lib/ash_phoenix_translations/csrf_protection\.ex"
        ]
      },
      
      # Strict mode for library development
      strict: true,
      parse_timeout: 5000,
      
      color: true,
      
      checks: %{
        enabled: [
          # Consistency Checks - Critical for library code
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          # Design Checks - Important for extensibility
          {Credo.Check.Design.AliasUsage,
           [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagTODO, [priority: :low, exit_status: 2]},

          # Readability Checks - Critical for public library
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, [priority: :high]},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          # Refactoring Checks - Keep code maintainable
          {Credo.Check.Refactor.ABCSize, [priority: :low, max_size: 50]},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapJoin, []},
          # {Credo.Check.Refactor.MapMap, []}, # Moved to disabled
          # Disabled: Ash extensions naturally have many dependencies due to framework integration
          # {Credo.Check.Refactor.ModuleDependencies, [priority: :low, max_deps: 10]},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          # {Credo.Check.Refactor.NegatedConditionsWithElse, []}, # Moved to disabled
          {Credo.Check.Refactor.Nesting, [priority: :low, max_nesting: 3]},
          # {Credo.Check.Refactor.PipeChainStart, []}, # Moved to disabled
          {Credo.Check.Refactor.RejectReject, []},
          # {Credo.Check.Refactor.UnlessWithElse, []}, # Moved to disabled
          {Credo.Check.Refactor.WithClauses, []},

          # Warning Checks - Catch potential issues
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.LazyLogging, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []}
        ],
        
        disabled: [
          # Disabled checks with reasons:
          
          # This check is too opinionated for DSL-heavy library code
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          
          # These conflict with common Elixir patterns in our codebase
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.MapMap, []},
          
          # Not compatible with Elixir 1.17.3
          {Credo.Check.Warning.LazyLogging, []},
          
          # Transformers may have longer functions due to DSL building logic
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          
          # These are stylistic preferences that conflict with Ash patterns
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          
          # May conflict with macro-heavy code in extensions
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, []}, # We use typespecs selectively
          
          # These can be overly restrictive for library initialization code
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.UnsafeToAtom, []}, # Common in DSL parsing
          
          # Specific to older Elixir versions
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.UnusedVariableNames, []},
          
          # These might conflict with Ash extension patterns
          {Credo.Check.Design.DuplicatedCode, []}, # DSL transformers may have similar patterns
          {Credo.Check.Design.SkipTestWithoutComment, []} # Test organization may vary
        ]
      },
      
      requires: [],
      
      plugins: []
    }
  ]
}