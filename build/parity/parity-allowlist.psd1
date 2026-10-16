@{
    # Parity allow-list for build/parity/Compare-MtTestResult.ps1.
    #
    # Encodes the intended result differences between Maester 2.x and 3.0 listed in
    # docs/proposals/maester-3.0-design.md section 5.3. Later milestones extend this file;
    # the differ never hard-codes a rule.
    #
    # Rule keys (all patterns are case-insensitive .NET regular expressions; a missing or
    # null value is compared as the empty string):
    #   Name        Unique rule name, reported in AllowListRule.
    #   Reference   Where the rule comes from (design section and item).
    #   Description Why the difference is intended.
    #   Field       Exact field name the rule applies to (Result, Severity, Title, Name, Block,
    #               HelpUrl, Tag, TestSkipped, SkippedReason, Presence, or a run-level field
    #               such as FailedCount). Required.
    #   FieldIsPattern  $true to treat Field as a pattern instead of an exact name.
    #   Id          Pattern on the row key (Id, or Name when Id is empty). Default: any.
    #   IdList      Exact row keys (case-insensitive). When present, the key must be listed.
    #   Old         Pattern on the old value. Default: any.
    #   New         Pattern on the new value. Default: any.
    #   NewRow      Hashtable of property path -> pattern matched against the NEW row
    #               (dotted paths allowed, e.g. 'ResultDetail.TestSkipped'). All must match.
    #               A rule with NewRow never matches when the new row is absent.
    #   OldRow      Same, against the OLD row.
    #   NewRun      Same, against the NEW run's top-level object (e.g. InvokeCommand).
    #
    # Presence differences use Field 'Presence': Old is the old row's Result (empty when
    # the row is missing from the old file) and New is the new row's Result (empty when
    # missing from the new file). Tag differences are reported one tag at a time: an
    # added tag has an empty Old, a removed tag has an empty New.
    #
    # Run-level count and Result differences are allow-listed by the differ itself (rule
    # name 'DerivedFromAllowListedRows') when every row-level Result and Presence
    # difference is allow-listed and the counts reconcile with those row changes. They
    # are not listed here.

    # Deny rules are evaluated before Rules. A difference matching a deny rule is never
    # allow-listed, whatever Rules say.
    Deny  = @(
        @{
            Name        = 'FailedToSkippedNeverAllowListed'
            Reference   = '5.3 item 2'
            Description = 'A Failed row that becomes Skipped hides a finding. It is never allow-listed: the parity differ flags it and the function is fixed. This also covers 5.3 item 10 (Failed -> Skipped/ServiceNotConnected), which must be reviewed per row.'
            Field       = 'Result'
            Old         = '^Failed$'
            New         = '^Skipped$'
        }
    )

    Rules = @(
        # 5.3 item 1: uncaught exceptions in native tests are always Error.
        @{
            Name        = 'NativeUncaughtExceptionIsError'
            Reference   = '5.3 item 1'
            Description = '2.x reports Failed for most exception types; a native test that throws is Error/TestError. Pester rows keep the 2.x rule, so the rule requires Format Native.'
            Field       = 'Result'
            Old         = '^Failed$'
            New         = '^Error$'
            NewRow      = @{ Format = '^Native$'; ReasonCode = '^TestError$' }
        }
        @{
            Name        = 'NativeErrorDropsTestSkippedMarker'
            Reference   = '5.3 item 1'
            Description = 'Rows that were Error through the boilerplate -SkippedBecause Error look the same in 3.0, only without the TestSkipped = Error marker.'
            Field       = 'TestSkipped'
            Old         = '^Error$'
            New         = '^$'
            NewRow      = @{ Format = '^Native$'; ReasonCode = '^TestError$' }
        }
        @{
            Name        = 'NativeErrorReasonText'
            Reference   = '5.3 item 1'
            Description = 'The skipped-reason text of an engine-caught error is the exception message, not the boilerplate error text.'
            Field       = 'SkippedReason'
            NewRow      = @{ Format = '^Native$'; ReasonCode = '^TestError$' }
        }

        # 5.3 item 2: $null meaning not applicable, for the listed functions only.
        @{
            Name        = 'NullReturnNotApplicable'
            Reference   = '5.3 item 2'
            Description = 'Thirteen functions (8 Global Secure Access, 5 AD) return $null to mean not applicable behind a null-guard wrapper, so 2.x reports Passed. They are rewritten to -SkippedBecause NotApplicable. Only Passed -> Skipped is allowed; Failed -> Skipped is denied above.'
            Field       = 'Result'
            Old         = '^Passed$'
            New         = '^Skipped$'
            NewRow      = @{ ReasonCode = '^(NotApplicable|NoResult)$' }
            # TODO(M2): fill with the 13 IDs when the functions are rewritten. Until then the
            # rule matches nothing, so every Passed -> Skipped change is flagged.
            IdList      = @()
        }

        # 5.3 item 3: a family that is deselected, gated, empty or failed gives one row on the parent ID.
        @{
            Name        = 'FamilyParentRow'
            Reference   = '5.3 item 3, section 10'
            Description = 'A family with no instance rows gives one row on its parent ID.'
            Field       = 'Presence'
            Id          = '^(MT\.1024|MT\.1033|MT\.1034|MT\.1059|MT1060)$'
            Old         = '^$'
            NewRow      = @{ ReasonCode = '^(NoInstances|InstanceSourceFailed|InvalidInstanceId|NotSelected|ExcludedByTag|ExcludedById|DisabledByConfig|ServiceNotConnected|ServiceNotRegistered|LicenseNotFound|TenantTypeMismatch|CloudMismatch|PlatformMismatch)$' }
        }

        # 5.3 item 4: MT.1022 and MT.1023 gain the Describe tags that 2.x drops inside a Context.
        @{
            Name        = 'ContextNestedDescribeTags'
            Reference   = '5.3 item 4, section 4'
            Description = '2.x drops Describe tags for tests nested in a Context; the attribute carries them.'
            Field       = 'Tag'
            IdList      = @('MT.1022', 'MT.1023')
            Old         = '^$'
            New         = '^(Maester|CA)$'
        }

        # 5.3 item 6: files that fail to load give LoadFailed rows.
        @{
            Name        = 'LoadFailedRow'
            Reference   = '5.3 item 6'
            Description = 'A Pester file that fails discovery, or a custom native file that fails to load, gives one Error/LoadFailed row per statically known ID. 2.x gives no rows.'
            Field       = 'Presence'
            Old         = '^$'
            New         = '^Error$'
            NewRow      = @{ ReasonCode = '^LoadFailed$' }
        }

        # 5.3 item 9: HelpUrl filled from the suite template.
        @{
            Name        = 'HelpUrlFromTemplate'
            Reference   = '5.3 item 9'
            Description = 'About 510 rows whose It name has no "See https" suffix have an empty HelpUrl in 2.x; 3.0 fills it from the suite template.'
            Field       = 'HelpUrl'
            Old         = '^$'
            New         = '^https://'
        }

        # 5.3 item 10: a check without a connection guard whose service is not connected.
        @{
            Name        = 'ServiceNotConnectedFromError'
            Reference   = '5.3 item 10'
            Description = '2.x reports Error when a check has no connection guard; 3.0 reports Skipped/ServiceNotConnected. Failed -> Skipped is denied above and needs review per row.'
            Field       = 'Result'
            Old         = '^Error$'
            New         = '^Skipped$'
            NewRow      = @{ ReasonCode = '^ServiceNotConnected$' }
        }
        @{
            Name        = 'ServiceNotConnectedSkipText'
            Reference   = '5.3 item 10'
            Description = 'The engine fills the 2.x skip fields for a ServiceNotConnected row.'
            Field       = '^(TestSkipped|SkippedReason)$'
            FieldIsPattern = $true
            NewRow      = @{ ReasonCode = '^ServiceNotConnected$' }
        }

        # 5.3 item 11: selection fixes.
        @{
            Name        = 'TagAllOrFullSelectsTests'
            Reference   = '5.3 item 11'
            Description = '-Tag All and -Tag Full select tests in 3.0; 2.x selected none, so rows are new.'
            Field       = 'Presence'
            Old         = '^$'
            NewRun      = @{ InvokeCommand = '-Tag\s+(\S+,\s*)*[''"]?(All|Full)\b' }
        }
        @{
            Name        = 'CallerExcludeTagHonoured'
            Reference   = '5.3 item 11'
            Description = 'A caller''s PesterConfiguration.Filter.ExcludeTag is honoured; 2.x discarded it whenever a default exclusion applied, so those tests ran.'
            Field       = 'Result'
            New         = '^NotRun$'
            NewRow      = @{ ReasonCode = '^ExcludedByTag$' }
        }
    )
}
