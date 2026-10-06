# Classified harness tools

Captured installed catalog: **646 tools** — **351 query**, **278 mutation**, **17 mixed**. In Codex, query entries move to URI pages while mutation and mixed entries stay native. In owned Claude, every entry is reached through a page: query links or typed mutation/mixed actions. Only hyperTUI, hyperTUI_action and present_ui remain native. The dispositions below describe the original Codex policy; catalog.json additionally records each Claude page disposition. Config readback proves Codex filtering, but filtered Codex model routing remains unverified. Filtered Claude model use is verified.

The catalog includes full schemas and classification reasons in [catalog.json](catalog.json). The separate [active public manifest](active-tools.json) lists 595 names and marks the already-running session as immutable; it is not the same manifest as a newly launched harness. Internal bookkeeping is excluded.

## Installed Codex MCP servers

624 tools.

### Query (346)

| Server | Exact tool name | Disposition |
| --- | --- | --- |
| `apple-notes` | `doctor` | URI page: `hypertui://tools/codex/apple-notes/doctor` |
| `apple-notes` | `export-notes-json` | URI page: `hypertui://tools/codex/apple-notes/export-notes-json` |
| `apple-notes` | `fetch-attachment` | URI page: `hypertui://tools/codex/apple-notes/fetch-attachment` |
| `apple-notes` | `get-checklist-state` | URI page: `hypertui://tools/codex/apple-notes/get-checklist-state` |
| `apple-notes` | `get-default-location` | URI page: `hypertui://tools/codex/apple-notes/get-default-location` |
| `apple-notes` | `get-note-by-id` | URI page: `hypertui://tools/codex/apple-notes/get-note-by-id` |
| `apple-notes` | `get-note-content` | URI page: `hypertui://tools/codex/apple-notes/get-note-content` |
| `apple-notes` | `get-note-details` | URI page: `hypertui://tools/codex/apple-notes/get-note-details` |
| `apple-notes` | `get-note-link` | URI page: `hypertui://tools/codex/apple-notes/get-note-link` |
| `apple-notes` | `get-note-markdown` | URI page: `hypertui://tools/codex/apple-notes/get-note-markdown` |
| `apple-notes` | `get-note-metadata` | URI page: `hypertui://tools/codex/apple-notes/get-note-metadata` |
| `apple-notes` | `get-note-plaintext` | URI page: `hypertui://tools/codex/apple-notes/get-note-plaintext` |
| `apple-notes` | `get-notes-stats` | URI page: `hypertui://tools/codex/apple-notes/get-notes-stats` |
| `apple-notes` | `get-selected-notes` | URI page: `hypertui://tools/codex/apple-notes/get-selected-notes` |
| `apple-notes` | `get-sync-status` | URI page: `hypertui://tools/codex/apple-notes/get-sync-status` |
| `apple-notes` | `health-check` | URI page: `hypertui://tools/codex/apple-notes/health-check` |
| `apple-notes` | `list-accounts` | URI page: `hypertui://tools/codex/apple-notes/list-accounts` |
| `apple-notes` | `list-attachments` | URI page: `hypertui://tools/codex/apple-notes/list-attachments` |
| `apple-notes` | `list-folders` | URI page: `hypertui://tools/codex/apple-notes/list-folders` |
| `apple-notes` | `list-notes` | URI page: `hypertui://tools/codex/apple-notes/list-notes` |
| `apple-notes` | `list-shared-notes` | URI page: `hypertui://tools/codex/apple-notes/list-shared-notes` |
| `apple-notes` | `search-notes` | URI page: `hypertui://tools/codex/apple-notes/search-notes` |
| `codex_apps` | `chatgpt_space.find_pages` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.find_pages` |
| `codex_apps` | `chatgpt_space.get_artifact_execution_status` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.get_artifact_execution_status` |
| `codex_apps` | `chatgpt_space.get_page_auto_update` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.get_page_auto_update` |
| `codex_apps` | `chatgpt_space.get_page_sharing` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.get_page_sharing` |
| `codex_apps` | `chatgpt_space.get_sharing_availability` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.get_sharing_availability` |
| `codex_apps` | `chatgpt_space.get_space` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.get_space` |
| `codex_apps` | `chatgpt_space.get_space_sharing` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.get_space_sharing` |
| `codex_apps` | `chatgpt_space.inspect_page_reference` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.inspect_page_reference` |
| `codex_apps` | `chatgpt_space.list_page_automations` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.list_page_automations` |
| `codex_apps` | `chatgpt_space.list_page_comments` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.list_page_comments` |
| `codex_apps` | `chatgpt_space.list_pages` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.list_pages` |
| `codex_apps` | `chatgpt_space.list_spaces` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.list_spaces` |
| `codex_apps` | `chatgpt_space.read_page` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.read_page` |
| `codex_apps` | `chatgpt_space.read_page_changes` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.read_page_changes` |
| `codex_apps` | `chatgpt_space.read_page_reference` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.read_page_reference` |
| `codex_apps` | `chatgpt_space.read_page_transcript` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.read_page_transcript` |
| `codex_apps` | `chatgpt_space.search_sharing_recipients` | URI page: `hypertui://tools/codex/codex_apps/chatgpt_space.search_sharing_recipients` |
| `codex_apps` | `codex_document_control.get_document_tool_schemas` | URI page: `hypertui://tools/codex/codex_apps/codex_document_control.get_document_tool_schemas` |
| `codex_apps` | `codex_document_control.list_document_sessions` | URI page: `hypertui://tools/codex/codex_apps/codex_document_control.list_document_sessions` |
| `codex_apps` | `codex_security_cloud.defense_factory_billing_opt_in_get` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_billing_opt_in_get` |
| `codex_apps` | `codex_security_cloud.defense_factory_bootstrap` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_bootstrap` |
| `codex_apps` | `codex_security_cloud.defense_factory_dashboard_activity` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_dashboard_activity` |
| `codex_apps` | `codex_security_cloud.defense_factory_dashboard_findings` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_dashboard_findings` |
| `codex_apps` | `codex_security_cloud.defense_factory_dashboard_findings_summary` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_dashboard_findings_summary` |
| `codex_apps` | `codex_security_cloud.defense_factory_dashboard_repositories` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_dashboard_repositories` |
| `codex_apps` | `codex_security_cloud.defense_factory_dashboard_scans` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_dashboard_scans` |
| `codex_apps` | `codex_security_cloud.defense_factory_environments_list` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_environments_list` |
| `codex_apps` | `codex_security_cloud.defense_factory_environments_search` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_environments_search` |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_export` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_findings_export` |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_get` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_findings_get` |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_list` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_findings_list` |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_summary` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_findings_summary` |
| `codex_apps` | `codex_security_cloud.defense_factory_github_access` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_github_access` |
| `codex_apps` | `codex_security_cloud.defense_factory_github_get` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_github_get` |
| `codex_apps` | `codex_security_cloud.defense_factory_github_repositories` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_github_repositories` |
| `codex_apps` | `codex_security_cloud.defense_factory_github_search` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_github_search` |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_cost` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_monitoring_cost` |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_get` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_monitoring_get` |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_list` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_monitoring_list` |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_metadata` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_monitoring_metadata` |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_scan_get` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_monitoring_scan_get` |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_scans` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_monitoring_scans` |
| `codex_apps` | `codex_security_cloud.defense_factory_notifications_connections` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_notifications_connections` |
| `codex_apps` | `codex_security_cloud.defense_factory_notifications_validate` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_notifications_validate` |
| `codex_apps` | `codex_security_cloud.defense_factory_scan_history` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_scan_history` |
| `codex_apps` | `codex_security_cloud.defense_factory_usage_get` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_usage_get` |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_artifact` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_workflow_artifact` |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_definition` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_workflow_definition` |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_get` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_workflow_get` |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_list` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_workflow_list` |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_output` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_workflow_output` |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_repositories` | URI page: `hypertui://tools/codex/codex_apps/codex_security_cloud.defense_factory_workflow_repositories` |
| `codex_apps` | `github.compare_commits` | URI page: `hypertui://tools/codex/codex_apps/github.compare_commits` |
| `codex_apps` | `github.download_user_content` | URI page: `hypertui://tools/codex/codex_apps/github.download_user_content` |
| `codex_apps` | `github.download_workflow_artifact` | URI page: `hypertui://tools/codex/codex_apps/github.download_workflow_artifact` |
| `codex_apps` | `github.fetch` | URI page: `hypertui://tools/codex/codex_apps/github.fetch` |
| `codex_apps` | `github.fetch_blob` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_blob` |
| `codex_apps` | `github.fetch_commit` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_commit` |
| `codex_apps` | `github.fetch_commit_workflow_runs` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_commit_workflow_runs` |
| `codex_apps` | `github.fetch_file` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_file` |
| `codex_apps` | `github.fetch_issue` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_issue` |
| `codex_apps` | `github.fetch_issue_comments` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_issue_comments` |
| `codex_apps` | `github.fetch_pr` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_pr` |
| `codex_apps` | `github.fetch_pr_comments` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_pr_comments` |
| `codex_apps` | `github.fetch_pr_file_patch` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_pr_file_patch` |
| `codex_apps` | `github.fetch_pr_patch` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_pr_patch` |
| `codex_apps` | `github.fetch_workflow_job_logs` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_workflow_job_logs` |
| `codex_apps` | `github.fetch_workflow_job_steps` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_workflow_job_steps` |
| `codex_apps` | `github.fetch_workflow_run_artifacts` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_workflow_run_artifacts` |
| `codex_apps` | `github.fetch_workflow_run_jobs` | URI page: `hypertui://tools/codex/codex_apps/github.fetch_workflow_run_jobs` |
| `codex_apps` | `github.get_commit_combined_status` | URI page: `hypertui://tools/codex/codex_apps/github.get_commit_combined_status` |
| `codex_apps` | `github.get_issue_comment_reactions` | URI page: `hypertui://tools/codex/codex_apps/github.get_issue_comment_reactions` |
| `codex_apps` | `github.get_pr_diff` | URI page: `hypertui://tools/codex/codex_apps/github.get_pr_diff` |
| `codex_apps` | `github.get_pr_info` | URI page: `hypertui://tools/codex/codex_apps/github.get_pr_info` |
| `codex_apps` | `github.get_pr_mergeability` | URI page: `hypertui://tools/codex/codex_apps/github.get_pr_mergeability` |
| `codex_apps` | `github.get_pr_reactions` | URI page: `hypertui://tools/codex/codex_apps/github.get_pr_reactions` |
| `codex_apps` | `github.get_pr_review_comment_reactions` | URI page: `hypertui://tools/codex/codex_apps/github.get_pr_review_comment_reactions` |
| `codex_apps` | `github.get_pr_statuses` | URI page: `hypertui://tools/codex/codex_apps/github.get_pr_statuses` |
| `codex_apps` | `github.get_profile` | URI page: `hypertui://tools/codex/codex_apps/github.get_profile` |
| `codex_apps` | `github.get_repo` | URI page: `hypertui://tools/codex/codex_apps/github.get_repo` |
| `codex_apps` | `github.get_repo_collaborator_permission` | URI page: `hypertui://tools/codex/codex_apps/github.get_repo_collaborator_permission` |
| `codex_apps` | `github.get_user_login` | URI page: `hypertui://tools/codex/codex_apps/github.get_user_login` |
| `codex_apps` | `github.get_users_recent_prs_in_repo` | URI page: `hypertui://tools/codex/codex_apps/github.get_users_recent_prs_in_repo` |
| `codex_apps` | `github.list_installations` | URI page: `hypertui://tools/codex/codex_apps/github.list_installations` |
| `codex_apps` | `github.list_installed_accounts` | URI page: `hypertui://tools/codex/codex_apps/github.list_installed_accounts` |
| `codex_apps` | `github.list_pr_changed_filenames` | URI page: `hypertui://tools/codex/codex_apps/github.list_pr_changed_filenames` |
| `codex_apps` | `github.list_pull_request_review_threads` | URI page: `hypertui://tools/codex/codex_apps/github.list_pull_request_review_threads` |
| `codex_apps` | `github.list_pull_request_reviews` | URI page: `hypertui://tools/codex/codex_apps/github.list_pull_request_reviews` |
| `codex_apps` | `github.list_recent_issues` | URI page: `hypertui://tools/codex/codex_apps/github.list_recent_issues` |
| `codex_apps` | `github.list_repositories` | URI page: `hypertui://tools/codex/codex_apps/github.list_repositories` |
| `codex_apps` | `github.list_repositories_by_affiliation` | URI page: `hypertui://tools/codex/codex_apps/github.list_repositories_by_affiliation` |
| `codex_apps` | `github.list_repositories_by_installation` | URI page: `hypertui://tools/codex/codex_apps/github.list_repositories_by_installation` |
| `codex_apps` | `github.list_user_org_memberships` | URI page: `hypertui://tools/codex/codex_apps/github.list_user_org_memberships` |
| `codex_apps` | `github.list_user_orgs` | URI page: `hypertui://tools/codex/codex_apps/github.list_user_orgs` |
| `codex_apps` | `github.search` | URI page: `hypertui://tools/codex/codex_apps/github.search` |
| `codex_apps` | `github.search_branches` | URI page: `hypertui://tools/codex/codex_apps/github.search_branches` |
| `codex_apps` | `github.search_commits` | URI page: `hypertui://tools/codex/codex_apps/github.search_commits` |
| `codex_apps` | `github.search_installed_repositories_streaming` | URI page: `hypertui://tools/codex/codex_apps/github.search_installed_repositories_streaming` |
| `codex_apps` | `github.search_installed_repositories_v2` | URI page: `hypertui://tools/codex/codex_apps/github.search_installed_repositories_v2` |
| `codex_apps` | `github.search_issues` | URI page: `hypertui://tools/codex/codex_apps/github.search_issues` |
| `codex_apps` | `github.search_prs` | URI page: `hypertui://tools/codex/codex_apps/github.search_prs` |
| `codex_apps` | `github.search_repositories` | URI page: `hypertui://tools/codex/codex_apps/github.search_repositories` |
| `codex_apps` | `hotline.get_local_hotline` | URI page: `hypertui://tools/codex/codex_apps/hotline.get_local_hotline` |
| `codex_apps` | `near_io_little_world.read_room` | URI page: `hypertui://tools/codex/codex_apps/near_io_little_world.read_room` |
| `codex_apps` | `notion.ai-search` | URI page: `hypertui://tools/codex/codex_apps/notion.ai-search` |
| `codex_apps` | `notion.fetch` | URI page: `hypertui://tools/codex/codex_apps/notion.fetch` |
| `codex_apps` | `notion.notion-check-mcp-next-steps` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-check-mcp-next-steps` |
| `codex_apps` | `notion.notion-download-attachment` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-download-attachment` |
| `codex_apps` | `notion.notion-download-skill` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-download-skill` |
| `codex_apps` | `notion.notion-get-async-task` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-get-async-task` |
| `codex_apps` | `notion.notion-get-comments` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-get-comments` |
| `codex_apps` | `notion.notion-get-session-status` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-get-session-status` |
| `codex_apps` | `notion.notion-get-teams` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-get-teams` |
| `codex_apps` | `notion.notion-get-tool-access` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-get-tool-access` |
| `codex_apps` | `notion.notion-get-users` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-get-users` |
| `codex_apps` | `notion.notion-list-favorite-pages` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-list-favorite-pages` |
| `codex_apps` | `notion.notion-list-private-pages` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-list-private-pages` |
| `codex_apps` | `notion.notion-list-recent-pages` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-list-recent-pages` |
| `codex_apps` | `notion.notion-list-session-events` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-list-session-events` |
| `codex_apps` | `notion.notion-list-shared-pages` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-list-shared-pages` |
| `codex_apps` | `notion.notion-query-meeting-notes` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-query-meeting-notes` |
| `codex_apps` | `notion.notion-query-sessions` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-query-sessions` |
| `codex_apps` | `notion.notion-read-session-event` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-read-session-event` |
| `codex_apps` | `notion.notion-search-agents` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-search-agents` |
| `codex_apps` | `notion.notion-search-emails` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-search-emails` |
| `codex_apps` | `notion.notion-search-sessions` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-search-sessions` |
| `codex_apps` | `notion.notion-show-advanced-analysis-next-steps` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-show-advanced-analysis-next-steps` |
| `codex_apps` | `notion.notion-view-thread-content` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-view-thread-content` |
| `codex_apps` | `notion.notion-wait-session` | URI page: `hypertui://tools/codex/codex_apps/notion.notion-wait-session` |
| `codex_apps` | `notion.query-data-sources` | URI page: `hypertui://tools/codex/codex_apps/notion.query-data-sources` |
| `codex_apps` | `notion.query-multiple-data-sources` | URI page: `hypertui://tools/codex/codex_apps/notion.query-multiple-data-sources` |
| `codex_apps` | `notion.search` | URI page: `hypertui://tools/codex/codex_apps/notion.search` |
| `codex_apps` | `pets.get_pet_download_link` | URI page: `hypertui://tools/codex/codex_apps/pets.get_pet_download_link` |
| `codex_apps` | `pets.list_pets` | URI page: `hypertui://tools/codex/codex_apps/pets.list_pets` |
| `codex_apps` | `plugin_management.get_app_permissions` | URI page: `hypertui://tools/codex/codex_apps/plugin_management.get_app_permissions` |
| `codex_apps` | `plugin_management.get_plugin_dependencies` | URI page: `hypertui://tools/codex/codex_apps/plugin_management.get_plugin_dependencies` |
| `codex_apps` | `plugin_management.search_plugins` | URI page: `hypertui://tools/codex/codex_apps/plugin_management.search_plugins` |
| `codex_apps` | `pro_brief_workspace.list_files` | URI page: `hypertui://tools/codex/codex_apps/pro_brief_workspace.list_files` |
| `codex_apps` | `pro_brief_workspace.read_file` | URI page: `hypertui://tools/codex/codex_apps/pro_brief_workspace.read_file` |
| `codex_apps` | `pro_brief_workspace.read_image` | URI page: `hypertui://tools/codex/codex_apps/pro_brief_workspace.read_image` |
| `codex_apps` | `pro_brief_workspace.read_whatsapp` | URI page: `hypertui://tools/codex/codex_apps/pro_brief_workspace.read_whatsapp` |
| `codex_apps` | `pro_brief_workspace.read_whatsapp_transcript` | URI page: `hypertui://tools/codex/codex_apps/pro_brief_workspace.read_whatsapp_transcript` |
| `codex_apps` | `pro_brief_workspace.workspace_info` | URI page: `hypertui://tools/codex/codex_apps/pro_brief_workspace.workspace_info` |
| `codex_apps` | `safety_settings.get_family_info` | URI page: `hypertui://tools/codex/codex_apps/safety_settings.get_family_info` |
| `codex_apps` | `safety_settings.get_parental_controls` | URI page: `hypertui://tools/codex/codex_apps/safety_settings.get_parental_controls` |
| `codex_apps` | `safety_settings.get_trusted_contact` | URI page: `hypertui://tools/codex/codex_apps/safety_settings.get_trusted_contact` |
| `codex_apps` | `search_service.web_run` | URI page: `hypertui://tools/codex/codex_apps/search_service.web_run` |
| `codex_apps` | `sites.check_slug_availability` | URI page: `hypertui://tools/codex/codex_apps/sites.check_slug_availability` |
| `codex_apps` | `sites.get_database_overview` | URI page: `hypertui://tools/codex/codex_apps/sites.get_database_overview` |
| `codex_apps` | `sites.get_database_table_rows` | URI page: `hypertui://tools/codex/codex_apps/sites.get_database_table_rows` |
| `codex_apps` | `sites.get_deployment_status` | URI page: `hypertui://tools/codex/codex_apps/sites.get_deployment_status` |
| `codex_apps` | `sites.get_environment` | URI page: `hypertui://tools/codex/codex_apps/sites.get_environment` |
| `codex_apps` | `sites.get_environment_variables` | URI page: `hypertui://tools/codex/codex_apps/sites.get_environment_variables` |
| `codex_apps` | `sites.get_project` | URI page: `hypertui://tools/codex/codex_apps/sites.get_project` |
| `codex_apps` | `sites.get_site` | URI page: `hypertui://tools/codex/codex_apps/sites.get_site` |
| `codex_apps` | `sites.get_site_analytics_overview` | URI page: `hypertui://tools/codex/codex_apps/sites.get_site_analytics_overview` |
| `codex_apps` | `sites.get_site_version` | URI page: `hypertui://tools/codex/codex_apps/sites.get_site_version` |
| `codex_apps` | `sites.get_site_worker_logs` | URI page: `hypertui://tools/codex/codex_apps/sites.get_site_worker_logs` |
| `codex_apps` | `sites.list_custom_domains` | URI page: `hypertui://tools/codex/codex_apps/sites.list_custom_domains` |
| `codex_apps` | `sites.list_projects` | URI page: `hypertui://tools/codex/codex_apps/sites.list_projects` |
| `codex_apps` | `sites.list_site_analytics_events` | URI page: `hypertui://tools/codex/codex_apps/sites.list_site_analytics_events` |
| `codex_apps` | `sites.list_site_versions` | URI page: `hypertui://tools/codex/codex_apps/sites.list_site_versions` |
| `codex_apps` | `sites.list_sites` | URI page: `hypertui://tools/codex/codex_apps/sites.list_sites` |
| `codex_apps` | `sites.list_sites_creator_control_panel_projects` | URI page: `hypertui://tools/codex/codex_apps/sites.list_sites_creator_control_panel_projects` |
| `codex_apps` | `sites.query_site_analytics_event` | URI page: `hypertui://tools/codex/codex_apps/sites.query_site_analytics_event` |
| `codex_apps` | `sites.read_database_overview` | URI page: `hypertui://tools/codex/codex_apps/sites.read_database_overview` |
| `codex_apps` | `sites.read_database_table_rows` | URI page: `hypertui://tools/codex/codex_apps/sites.read_database_table_rows` |
| `codex_apps` | `sites.validate_suggested_schedule` | URI page: `hypertui://tools/codex/codex_apps/sites.validate_suggested_schedule` |
| `codex_apps` | `spotify.fetch_tracks` | URI page: `hypertui://tools/codex/codex_apps/spotify.fetch_tracks` |
| `codex_apps` | `spotify.get_currently_playing` | URI page: `hypertui://tools/codex/codex_apps/spotify.get_currently_playing` |
| `codex_apps` | `spotify.search` | URI page: `hypertui://tools/codex/codex_apps/spotify.search` |
| `codex_apps` | `uber.get_estimates_between_two_locations` | URI page: `hypertui://tools/codex/codex_apps/uber.get_estimates_between_two_locations` |
| `codex_apps` | `uber_eats.search` | URI page: `hypertui://tools/codex/codex_apps/uber_eats.search` |
| `codex_apps` | `vercel.aggregate_events` | URI page: `hypertui://tools/codex/codex_apps/vercel.aggregate_events` |
| `codex_apps` | `vercel.aggregate_pageviews` | URI page: `hypertui://tools/codex/codex_apps/vercel.aggregate_pageviews` |
| `codex_apps` | `vercel.count_events` | URI page: `hypertui://tools/codex/codex_apps/vercel.count_events` |
| `codex_apps` | `vercel.count_pageviews` | URI page: `hypertui://tools/codex/codex_apps/vercel.count_pageviews` |
| `codex_apps` | `vercel.create_observability_query` | URI page: `hypertui://tools/codex/codex_apps/vercel.create_observability_query` |
| `codex_apps` | `vercel.filter_project_envs` | URI page: `hypertui://tools/codex/codex_apps/vercel.filter_project_envs` |
| `codex_apps` | `vercel.get_active_attack_status` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_active_attack_status` |
| `codex_apps` | `vercel.get_agent_run` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_agent_run` |
| `codex_apps` | `vercel.get_agent_run_trace` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_agent_run_trace` |
| `codex_apps` | `vercel.get_ai_gateway_virtual_model_config` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_ai_gateway_virtual_model_config` |
| `codex_apps` | `vercel.get_ai_gateway_virtual_model_config_by_slug` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_ai_gateway_virtual_model_config_by_slug` |
| `codex_apps` | `vercel.get_auth_token` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_auth_token` |
| `codex_apps` | `vercel.get_auth_user` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_auth_user` |
| `codex_apps` | `vercel.get_bulk_availability` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_bulk_availability` |
| `codex_apps` | `vercel.get_bulk_price` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_bulk_price` |
| `codex_apps` | `vercel.get_bypass_ip` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_bypass_ip` |
| `codex_apps` | `vercel.get_check` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_check` |
| `codex_apps` | `vercel.get_configuration` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_configuration` |
| `codex_apps` | `vercel.get_connector` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_connector` |
| `codex_apps` | `vercel.get_connector_project_connection` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_connector_project_connection` |
| `codex_apps` | `vercel.get_contact_info_schema` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_contact_info_schema` |
| `codex_apps` | `vercel.get_custom_environment` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_custom_environment` |
| `codex_apps` | `vercel.get_deployment` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_deployment` |
| `codex_apps` | `vercel.get_deployment_check_run` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_deployment_check_run` |
| `codex_apps` | `vercel.get_deployment_file_contents` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_deployment_file_contents` |
| `codex_apps` | `vercel.get_domain_availability` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_domain_availability` |
| `codex_apps` | `vercel.get_domain_contact_verification` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_domain_contact_verification` |
| `codex_apps` | `vercel.get_domain_order` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_domain_order` |
| `codex_apps` | `vercel.get_domain_price` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_domain_price` |
| `codex_apps` | `vercel.get_domains_records_by_record_id` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_domains_records_by_record_id` |
| `codex_apps` | `vercel.get_drain` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_drain` |
| `codex_apps` | `vercel.get_edge_config_backup` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_edge_config_backup` |
| `codex_apps` | `vercel.get_edge_config_token` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_edge_config_token` |
| `codex_apps` | `vercel.get_firewall_config` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_firewall_config` |
| `codex_apps` | `vercel.get_flag` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_flag` |
| `codex_apps` | `vercel.get_flag_segment` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_flag_segment` |
| `codex_apps` | `vercel.get_flag_settings` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_flag_settings` |
| `codex_apps` | `vercel.get_git_deployment_context` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_git_deployment_context` |
| `codex_apps` | `vercel.get_kms_issuer` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_kms_issuer` |
| `codex_apps` | `vercel.get_microfrontends_config` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_microfrontends_config` |
| `codex_apps` | `vercel.get_microfrontends_config_for_project` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_microfrontends_config_for_project` |
| `codex_apps` | `vercel.get_observability_schema` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_observability_schema` |
| `codex_apps` | `vercel.get_order` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_order` |
| `codex_apps` | `vercel.get_project` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_project` |
| `codex_apps` | `vercel.get_project_check` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_project_check` |
| `codex_apps` | `vercel.get_project_deletion_link` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_project_deletion_link` |
| `codex_apps` | `vercel.get_project_env` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_project_env` |
| `codex_apps` | `vercel.get_project_trace` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_project_trace` |
| `codex_apps` | `vercel.get_remote_cache_status` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_remote_cache_status` |
| `codex_apps` | `vercel.get_rolling_release` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_rolling_release` |
| `codex_apps` | `vercel.get_rolling_release_billing_status` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_rolling_release_billing_status` |
| `codex_apps` | `vercel.get_rolling_release_config` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_rolling_release_config` |
| `codex_apps` | `vercel.get_runtime_errors` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_runtime_errors` |
| `codex_apps` | `vercel.get_runtime_logs` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_runtime_logs` |
| `codex_apps` | `vercel.get_session` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_session` |
| `codex_apps` | `vercel.get_session_command` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_session_command` |
| `codex_apps` | `vercel.get_session_command_logs` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_session_command_logs` |
| `codex_apps` | `vercel.get_session_snapshot` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_session_snapshot` |
| `codex_apps` | `vercel.get_shared_env_var` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_shared_env_var` |
| `codex_apps` | `vercel.get_storage_stores_by_id` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_storage_stores_by_id` |
| `codex_apps` | `vercel.get_team` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_team` |
| `codex_apps` | `vercel.get_team_access_request` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_team_access_request` |
| `codex_apps` | `vercel.get_tld` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_tld` |
| `codex_apps` | `vercel.get_tld_price` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_tld_price` |
| `codex_apps` | `vercel.get_toolbar_thread` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_toolbar_thread` |
| `codex_apps` | `vercel.get_vercel_ci_invocation` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_invocation` |
| `codex_apps` | `vercel.get_vercel_ci_invocation_logs` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_invocation_logs` |
| `codex_apps` | `vercel.get_vercel_ci_invocation_tree` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_invocation_tree` |
| `codex_apps` | `vercel.get_vercel_ci_job_definition` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_job_definition` |
| `codex_apps` | `vercel.get_vercel_ci_job_run` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_job_run` |
| `codex_apps` | `vercel.get_vercel_ci_job_run_logs` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_job_run_logs` |
| `codex_apps` | `vercel.get_vercel_ci_task_logs` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_task_logs` |
| `codex_apps` | `vercel.get_vercel_ci_task_run_logs` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_vercel_ci_task_run_logs` |
| `codex_apps` | `vercel.get_webhook` | URI page: `hypertui://tools/codex/codex_apps/vercel.get_webhook` |
| `codex_apps` | `vercel.list_access_group_members` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_access_group_members` |
| `codex_apps` | `vercel.list_access_group_projects` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_access_group_projects` |
| `codex_apps` | `vercel.list_agent_run_projects` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_agent_run_projects` |
| `codex_apps` | `vercel.list_agent_runs` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_agent_runs` |
| `codex_apps` | `vercel.list_aliases` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_aliases` |
| `codex_apps` | `vercel.list_billing_charges` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_billing_charges` |
| `codex_apps` | `vercel.list_bulk_redirect_versions` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_bulk_redirect_versions` |
| `codex_apps` | `vercel.list_bulk_redirects` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_bulk_redirects` |
| `codex_apps` | `vercel.list_certs` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_certs` |
| `codex_apps` | `vercel.list_check_runs` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_check_runs` |
| `codex_apps` | `vercel.list_connector_project_connections` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_connector_project_connections` |
| `codex_apps` | `vercel.list_connectors` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_connectors` |
| `codex_apps` | `vercel.list_contract_commitments` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_contract_commitments` |
| `codex_apps` | `vercel.list_deployment_aliases` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_deployment_aliases` |
| `codex_apps` | `vercel.list_deployment_events` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_deployment_events` |
| `codex_apps` | `vercel.list_deployment_files` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_deployment_files` |
| `codex_apps` | `vercel.list_deployments` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_deployments` |
| `codex_apps` | `vercel.list_domains` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_domains` |
| `codex_apps` | `vercel.list_drains` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_drains` |
| `codex_apps` | `vercel.list_event_types` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_event_types` |
| `codex_apps` | `vercel.list_feature_flag_sdk_keys` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_feature_flag_sdk_keys` |
| `codex_apps` | `vercel.list_flags` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_flags` |
| `codex_apps` | `vercel.list_flags_v2` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_flags_v2` |
| `codex_apps` | `vercel.list_integration_billing_plans` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_integration_billing_plans` |
| `codex_apps` | `vercel.list_integration_configuration_products` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_integration_configuration_products` |
| `codex_apps` | `vercel.list_integration_configurations` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_integration_configurations` |
| `codex_apps` | `vercel.list_microfrontends_group_projects` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_microfrontends_group_projects` |
| `codex_apps` | `vercel.list_named_sandboxes` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_named_sandboxes` |
| `codex_apps` | `vercel.list_private_link_endpoints` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_private_link_endpoints` |
| `codex_apps` | `vercel.list_project_connector_connections` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_project_connector_connections` |
| `codex_apps` | `vercel.list_project_custom_environments` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_project_custom_environments` |
| `codex_apps` | `vercel.list_project_domains` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_project_domains` |
| `codex_apps` | `vercel.list_project_route_versions` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_project_route_versions` |
| `codex_apps` | `vercel.list_project_routes` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_project_routes` |
| `codex_apps` | `vercel.list_projects` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_projects` |
| `codex_apps` | `vercel.list_promote_aliases` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_promote_aliases` |
| `codex_apps` | `vercel.list_session_commands` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_session_commands` |
| `codex_apps` | `vercel.list_session_snapshots` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_session_snapshots` |
| `codex_apps` | `vercel.list_sessions` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_sessions` |
| `codex_apps` | `vercel.list_supported_tlds` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_supported_tlds` |
| `codex_apps` | `vercel.list_team_members` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_team_members` |
| `codex_apps` | `vercel.list_teams` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_teams` |
| `codex_apps` | `vercel.list_toolbar_threads` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_toolbar_threads` |
| `codex_apps` | `vercel.list_user_events` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_user_events` |
| `codex_apps` | `vercel.list_vercel_ci_invocation_attempts` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_vercel_ci_invocation_attempts` |
| `codex_apps` | `vercel.list_vercel_ci_invocations` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_vercel_ci_invocations` |
| `codex_apps` | `vercel.list_vercel_ci_job_definitions` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_vercel_ci_job_definitions` |
| `codex_apps` | `vercel.list_vercel_ci_job_runs` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_vercel_ci_job_runs` |
| `codex_apps` | `vercel.list_vercel_ci_task_definitions` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_vercel_ci_task_definitions` |
| `codex_apps` | `vercel.list_vercel_ci_task_runs` | URI page: `hypertui://tools/codex/codex_apps/vercel.list_vercel_ci_task_runs` |
| `codex_apps` | `vercel.read_access_group` | URI page: `hypertui://tools/codex/codex_apps/vercel.read_access_group` |
| `codex_apps` | `vercel.read_access_group_project` | URI page: `hypertui://tools/codex/codex_apps/vercel.read_access_group_project` |
| `codex_apps` | `vercel.read_network` | URI page: `hypertui://tools/codex/codex_apps/vercel.read_network` |
| `codex_apps` | `vercel.read_private_link_endpoint` | URI page: `hypertui://tools/codex/codex_apps/vercel.read_private_link_endpoint` |
| `codex_apps` | `vercel.search_domains` | URI page: `hypertui://tools/codex/codex_apps/vercel.search_domains` |
| `codex_apps` | `vercel.search_repo` | URI page: `hypertui://tools/codex/codex_apps/vercel.search_repo` |
| `codex_apps` | `vercel.search_vercel_documentation` | URI page: `hypertui://tools/codex/codex_apps/vercel.search_vercel_documentation` |
| `event-stream` | `event_stream_status` | URI page: `hypertui://tools/codex/event-stream/event_stream_status` |
| `linear-graphql` | `auth_status` | URI page: `hypertui://tools/codex/linear-graphql/auth_status` |
| `linear-graphql` | `get_issue` | URI page: `hypertui://tools/codex/linear-graphql/get_issue` |
| `linear-graphql` | `graphql_query` | URI page: `hypertui://tools/codex/linear-graphql/graphql_query` |
| `linear-graphql-avanza-control` | `auth_status` | URI page: `hypertui://tools/codex/linear-graphql-avanza-control/auth_status` |
| `linear-graphql-avanza-control` | `get_issue` | URI page: `hypertui://tools/codex/linear-graphql-avanza-control/get_issue` |
| `linear-graphql-avanza-control` | `graphql_query` | URI page: `hypertui://tools/codex/linear-graphql-avanza-control/graphql_query` |
| `linear-graphql-tradeincode` | `auth_status` | URI page: `hypertui://tools/codex/linear-graphql-tradeincode/auth_status` |
| `linear-graphql-tradeincode` | `get_issue` | URI page: `hypertui://tools/codex/linear-graphql-tradeincode/get_issue` |
| `linear-graphql-tradeincode` | `graphql_query` | URI page: `hypertui://tools/codex/linear-graphql-tradeincode/graphql_query` |
| `macbook-credential-broker` | `credential_status` | URI page: `hypertui://tools/codex/macbook-credential-broker/credential_status` |
| `macbook-credential-broker` | `inspect_credential_target` | URI page: `hypertui://tools/codex/macbook-credential-broker/inspect_credential_target` |
| `messages` | `count_message_activity` | URI page: `hypertui://tools/codex/messages/count_message_activity` |
| `messages` | `find_chats` | URI page: `hypertui://tools/codex/messages/find_chats` |
| `messages` | `read_image` | URI page: `hypertui://tools/codex/messages/read_image` |
| `messages` | `read_messages` | URI page: `hypertui://tools/codex/messages/read_messages` |
| `messages` | `search_messages` | URI page: `hypertui://tools/codex/messages/search_messages` |
| `near-context` | `read_context` | URI page: `hypertui://tools/codex/near-context/read_context` |
| `near-context` | `read_public_profile` | URI page: `hypertui://tools/codex/near-context/read_public_profile` |
| `near-context` | `search_context` | URI page: `hypertui://tools/codex/near-context/search_context` |

### Mutation (268)

| Server | Exact tool name | Disposition |
| --- | --- | --- |
| `apple-notes` | `append-to-note` | Retained native |
| `apple-notes` | `batch-delete-notes` | Retained native |
| `apple-notes` | `batch-move-notes` | Retained native |
| `apple-notes` | `create-folder` | Retained native |
| `apple-notes` | `create-note` | Retained native |
| `apple-notes` | `delete-folder` | Retained native |
| `apple-notes` | `delete-note` | Retained native |
| `apple-notes` | `move-note` | Retained native |
| `apple-notes` | `save-attachment` | Retained native |
| `apple-notes` | `show-account` | Retained native |
| `apple-notes` | `show-attachment` | Retained native |
| `apple-notes` | `show-folder` | Retained native |
| `apple-notes` | `show-note` | Retained native |
| `apple-notes` | `update-note` | Retained native |
| `codex_apps` | `chatgpt_space.attach_automation_to_page` | Retained native |
| `codex_apps` | `chatgpt_space.create_canvas` | Retained native |
| `codex_apps` | `chatgpt_space.create_controller_automation` | Retained native |
| `codex_apps` | `chatgpt_space.create_page` | Retained native |
| `codex_apps` | `chatgpt_space.create_page_visualization` | Retained native |
| `codex_apps` | `chatgpt_space.create_presentation` | Retained native |
| `codex_apps` | `chatgpt_space.create_space` | Retained native |
| `codex_apps` | `chatgpt_space.create_spreadsheet` | Retained native |
| `codex_apps` | `chatgpt_space.edit_page` | Retained native |
| `codex_apps` | `chatgpt_space.manage_page_comment` | Retained native |
| `codex_apps` | `chatgpt_space.move_page` | Retained native |
| `codex_apps` | `chatgpt_space.patch_page` | Retained native |
| `codex_apps` | `chatgpt_space.progress_update` | Retained native |
| `codex_apps` | `chatgpt_space.reply_page_comment` | Retained native |
| `codex_apps` | `chatgpt_space.run_page_auto_update` | Retained native |
| `codex_apps` | `chatgpt_space.set_page_auto_update` | Retained native |
| `codex_apps` | `chatgpt_space.trash_page` | Retained native |
| `codex_apps` | `chatgpt_space.update_page_sharing` | Retained native |
| `codex_apps` | `chatgpt_space.update_space_sharing` | Retained native |
| `codex_apps` | `chatgpt_space.write_page_reference` | Retained native |
| `codex_apps` | `clockwork.get_user_routine_v2` | Retained native |
| `codex_apps` | `clockwork.mutate_user_routine_v2` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_billing_opt_in_update` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_environments_create_default` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_chat` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_close` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_create_pr` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_feedback` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_findings_update` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_create` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_delete` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_recover` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_monitoring_update` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_notifications_test` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_onboarding_update` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_cancel` | Retained native |
| `codex_apps` | `codex_security_cloud.defense_factory_workflow_launch` | Retained native |
| `codex_apps` | `convex.add_convex_to_existing_project` | Retained native |
| `codex_apps` | `convex.get_convex_scaling_guidance` | Retained native |
| `codex_apps` | `convex.get_runbook` | Retained native |
| `codex_apps` | `convex.start_convex_app` | Retained native |
| `codex_apps` | `github.add_comment_to_issue` | Retained native |
| `codex_apps` | `github.add_issue_assignees` | Retained native |
| `codex_apps` | `github.add_issue_labels` | Retained native |
| `codex_apps` | `github.add_reaction_to_issue_comment` | Retained native |
| `codex_apps` | `github.add_reaction_to_pr` | Retained native |
| `codex_apps` | `github.add_reaction_to_pr_review_comment` | Retained native |
| `codex_apps` | `github.add_review_to_pr` | Retained native |
| `codex_apps` | `github.convert_pull_request_to_draft` | Retained native |
| `codex_apps` | `github.create_blob` | Retained native |
| `codex_apps` | `github.create_branch` | Retained native |
| `codex_apps` | `github.create_commit` | Retained native |
| `codex_apps` | `github.create_file` | Retained native |
| `codex_apps` | `github.create_issue` | Retained native |
| `codex_apps` | `github.create_pull_request` | Retained native |
| `codex_apps` | `github.create_tree` | Retained native |
| `codex_apps` | `github.delete_file` | Retained native |
| `codex_apps` | `github.dismiss_pull_request_review` | Retained native |
| `codex_apps` | `github.enable_auto_merge` | Retained native |
| `codex_apps` | `github.label_pr` | Retained native |
| `codex_apps` | `github.lock_issue_conversation` | Retained native |
| `codex_apps` | `github.mark_pull_request_ready_for_review` | Retained native |
| `codex_apps` | `github.merge_pull_request` | Retained native |
| `codex_apps` | `github.remove_issue_assignees` | Retained native |
| `codex_apps` | `github.remove_issue_label` | Retained native |
| `codex_apps` | `github.remove_pull_request_reviewers` | Retained native |
| `codex_apps` | `github.remove_reaction_from_issue_comment` | Retained native |
| `codex_apps` | `github.remove_reaction_from_pr` | Retained native |
| `codex_apps` | `github.remove_reaction_from_pr_review_comment` | Retained native |
| `codex_apps` | `github.reply_to_review_comment` | Retained native |
| `codex_apps` | `github.request_pull_request_reviewers` | Retained native |
| `codex_apps` | `github.rerun_failed_workflow_run_jobs` | Retained native |
| `codex_apps` | `github.rerun_workflow_job` | Retained native |
| `codex_apps` | `github.resolve_review_thread` | Retained native |
| `codex_apps` | `github.unlock_issue_conversation` | Retained native |
| `codex_apps` | `github.unresolve_review_thread` | Retained native |
| `codex_apps` | `github.update_file` | Retained native |
| `codex_apps` | `github.update_issue` | Retained native |
| `codex_apps` | `github.update_issue_comment` | Retained native |
| `codex_apps` | `github.update_pull_request` | Retained native |
| `codex_apps` | `github.update_ref` | Retained native |
| `codex_apps` | `github.update_review_comment` | Retained native |
| `codex_apps` | `notion.notion-convert-page-to-skill` | Retained native |
| `codex_apps` | `notion.notion-create-attachment` | Retained native |
| `codex_apps` | `notion.notion-create-comment` | Retained native |
| `codex_apps` | `notion.notion-create-database` | Retained native |
| `codex_apps` | `notion.notion-create-file-upload` | Retained native |
| `codex_apps` | `notion.notion-create-folder` | Retained native |
| `codex_apps` | `notion.notion-create-pages` | Retained native |
| `codex_apps` | `notion.notion-create-view` | Retained native |
| `codex_apps` | `notion.notion-duplicate-page` | Retained native |
| `codex_apps` | `notion.notion-move-pages` | Retained native |
| `codex_apps` | `notion.notion-restore-pages` | Retained native |
| `codex_apps` | `notion.notion-send-message-to-session` | Retained native |
| `codex_apps` | `notion.notion-spawn-session` | Retained native |
| `codex_apps` | `notion.notion-stop-session` | Retained native |
| `codex_apps` | `notion.notion-update-data-source` | Retained native |
| `codex_apps` | `notion.notion-update-folder` | Retained native |
| `codex_apps` | `notion.notion-update-page` | Retained native |
| `codex_apps` | `notion.notion-update-view` | Retained native |
| `codex_apps` | `notion.notion-upload-skill` | Retained native |
| `codex_apps` | `pets.adopt` | Retained native |
| `codex_apps` | `pets.create_pet` | Retained native |
| `codex_apps` | `pets.delete_pet` | Retained native |
| `codex_apps` | `pets.prepare_pet_upload` | Retained native |
| `codex_apps` | `pets.select_pet` | Retained native |
| `codex_apps` | `pets.share_pet` | Retained native |
| `codex_apps` | `pets.unshare_pet` | Retained native |
| `codex_apps` | `pets.update_pet` | Retained native |
| `codex_apps` | `plugin_management.suggest_plugins` | Retained native |
| `codex_apps` | `plugin_management.uninstall_app` | Retained native |
| `codex_apps` | `plugin_management.update_app_permissions` | Retained native |
| `codex_apps` | `pro_brief_workspace.write_file` | Retained native |
| `codex_apps` | `safety_settings.update_parental_control` | Retained native |
| `codex_apps` | `sites.add_custom_domain` | Retained native |
| `codex_apps` | `sites.change_site_slug` | Retained native |
| `codex_apps` | `sites.create_schedule` | Retained native |
| `codex_apps` | `sites.create_site` | Retained native |
| `codex_apps` | `sites.create_source_repository_write_credential` | Retained native |
| `codex_apps` | `sites.delete_site` | Retained native |
| `codex_apps` | `sites.deploy_private_site_version` | Retained native |
| `codex_apps` | `sites.deploy_site_version` | Retained native |
| `codex_apps` | `sites.generate_siwc_bypass_token` | Retained native |
| `codex_apps` | `sites.refresh_custom_domain_status` | Retained native |
| `codex_apps` | `sites.remove_custom_domain` | Retained native |
| `codex_apps` | `sites.save_site_version` | Retained native |
| `codex_apps` | `sites.save_version_and_deploy_private` | Retained native |
| `codex_apps` | `sites.update_access` | Retained native |
| `codex_apps` | `sites.update_environment` | Retained native |
| `codex_apps` | `sites.update_environment_variables` | Retained native |
| `codex_apps` | `sites.update_site_access` | Retained native |
| `codex_apps` | `sites.update_site_metadata` | Retained native |
| `codex_apps` | `spotify.generate_playlist` | Retained native |
| `codex_apps` | `spotify.remove_from_library` | Retained native |
| `codex_apps` | `spotify.save_to_library` | Retained native |
| `codex_apps` | `uber.publish_analytics_events` | Retained native |
| `codex_apps` | `uber_eats.publish_analytics` | Retained native |
| `codex_apps` | `vercel.accept_project_transfer_request` | Retained native |
| `codex_apps` | `vercel.activate_kms_signing_key` | Retained native |
| `codex_apps` | `vercel.add_project_domain` | Retained native |
| `codex_apps` | `vercel.add_route` | Retained native |
| `codex_apps` | `vercel.add_toolbar_reaction` | Retained native |
| `codex_apps` | `vercel.approve_rolling_release_stage` | Retained native |
| `codex_apps` | `vercel.artifact_query` | Retained native |
| `codex_apps` | `vercel.assign_alias` | Retained native |
| `codex_apps` | `vercel.cancel_deployment` | Retained native |
| `codex_apps` | `vercel.change_toolbar_thread_resolve_status` | Retained native |
| `codex_apps` | `vercel.complete_rolling_release` | Retained native |
| `codex_apps` | `vercel.create_api_keys` | Retained native |
| `codex_apps` | `vercel.create_check` | Retained native |
| `codex_apps` | `vercel.create_deployment` | Retained native |
| `codex_apps` | `vercel.create_deployment_check_run` | Retained native |
| `codex_apps` | `vercel.create_drain` | Retained native |
| `codex_apps` | `vercel.create_edge_config_token` | Retained native |
| `codex_apps` | `vercel.create_flag` | Retained native |
| `codex_apps` | `vercel.create_git_project` | Retained native |
| `codex_apps` | `vercel.create_kms_issuer_policy` | Retained native |
| `codex_apps` | `vercel.create_kms_signing_key` | Retained native |
| `codex_apps` | `vercel.create_private_link_endpoint` | Retained native |
| `codex_apps` | `vercel.create_project` | Retained native |
| `codex_apps` | `vercel.create_project_env` | Retained native |
| `codex_apps` | `vercel.create_sandboxes_sessions_by_session_id_snapshot_v2` | Retained native |
| `codex_apps` | `vercel.create_sandboxes_sessions_by_session_id_snapshot_v3` | Retained native |
| `codex_apps` | `vercel.create_sandboxes_v2` | Retained native |
| `codex_apps` | `vercel.create_sandboxes_v3` | Retained native |
| `codex_apps` | `vercel.create_sandboxes_v4` | Retained native |
| `codex_apps` | `vercel.create_sdk_key` | Retained native |
| `codex_apps` | `vercel.create_session_directory` | Retained native |
| `codex_apps` | `vercel.create_storage_stores_blob` | Retained native |
| `codex_apps` | `vercel.edit_project_env` | Retained native |
| `codex_apps` | `vercel.edit_route` | Retained native |
| `codex_apps` | `vercel.edit_toolbar_message` | Retained native |
| `codex_apps` | `vercel.extend_session_timeout` | Retained native |
| `codex_apps` | `vercel.generate_route` | Retained native |
| `codex_apps` | `vercel.get_access_to_vercel_url` | Retained native |
| `codex_apps` | `vercel.get_named_sandbox` | Retained native |
| `codex_apps` | `vercel.get_project_token` | Retained native |
| `codex_apps` | `vercel.import-claude-design-from-url` | Retained native |
| `codex_apps` | `vercel.invalidate_by_src_images` | Retained native |
| `codex_apps` | `vercel.invalidate_by_tags` | Retained native |
| `codex_apps` | `vercel.issue_cert` | Retained native |
| `codex_apps` | `vercel.join_team` | Retained native |
| `codex_apps` | `vercel.kill_session_command` | Retained native |
| `codex_apps` | `vercel.patch_edge_config_items` | Retained native |
| `codex_apps` | `vercel.patch_edge_config_schema` | Retained native |
| `codex_apps` | `vercel.patch_url_protection_bypass` | Retained native |
| `codex_apps` | `vercel.pause_project` | Retained native |
| `codex_apps` | `vercel.put_firewall_config` | Retained native |
| `codex_apps` | `vercel.read_session_file` | Retained native |
| `codex_apps` | `vercel.record_events` | Retained native |
| `codex_apps` | `vercel.replace_connector_trigger_destinations` | Retained native |
| `codex_apps` | `vercel.replace_domain_dns_records` | Retained native |
| `codex_apps` | `vercel.reply_to_toolbar_thread` | Retained native |
| `codex_apps` | `vercel.request_promote` | Retained native |
| `codex_apps` | `vercel.request_rollback` | Retained native |
| `codex_apps` | `vercel.rerequest_check` | Retained native |
| `codex_apps` | `vercel.restore_edge_config_backup` | Retained native |
| `codex_apps` | `vercel.retry_vercel_ci_invocation` | Retained native |
| `codex_apps` | `vercel.revoke_kms_signing_key` | Retained native |
| `codex_apps` | `vercel.sign_kms_message` | Retained native |
| `codex_apps` | `vercel.sign_kms_token` | Retained native |
| `codex_apps` | `vercel.stage_redirects` | Retained native |
| `codex_apps` | `vercel.stage_routes` | Retained native |
| `codex_apps` | `vercel.start_rolling_release` | Retained native |
| `codex_apps` | `vercel.stop_session` | Retained native |
| `codex_apps` | `vercel.test_drain` | Retained native |
| `codex_apps` | `vercel.unpause_project` | Retained native |
| `codex_apps` | `vercel.update_ai_gateway_virtual_model_config_by_slug` | Retained native |
| `codex_apps` | `vercel.update_attack_challenge_mode` | Retained native |
| `codex_apps` | `vercel.update_check` | Retained native |
| `codex_apps` | `vercel.update_connector` | Retained native |
| `codex_apps` | `vercel.update_deployment_check_run` | Retained native |
| `codex_apps` | `vercel.update_drain` | Retained native |
| `codex_apps` | `vercel.update_edge_config` | Retained native |
| `codex_apps` | `vercel.update_flag` | Retained native |
| `codex_apps` | `vercel.update_flag_segment` | Retained native |
| `codex_apps` | `vercel.update_flag_settings` | Retained native |
| `codex_apps` | `vercel.update_kms_issuer` | Retained native |
| `codex_apps` | `vercel.update_kms_issuer_policy` | Retained native |
| `codex_apps` | `vercel.update_network` | Retained native |
| `codex_apps` | `vercel.update_private_link_endpoint` | Retained native |
| `codex_apps` | `vercel.update_project` | Retained native |
| `codex_apps` | `vercel.update_project_check` | Retained native |
| `codex_apps` | `vercel.update_project_protection_bypass` | Retained native |
| `codex_apps` | `vercel.update_record` | Retained native |
| `codex_apps` | `vercel.update_rolling_release_config` | Retained native |
| `codex_apps` | `vercel.update_sandbox` | Retained native |
| `codex_apps` | `vercel.update_session_network_policy` | Retained native |
| `codex_apps` | `vercel.update_shared_env_variable` | Retained native |
| `codex_apps` | `vercel.upload_artifact` | Retained native |
| `codex_apps` | `vercel.upload_file` | Retained native |
| `codex_apps` | `vercel.upsert_connector_project_connection` | Retained native |
| `codex_apps` | `vercel.web_fetch_vercel_url` | Retained native |
| `codex_apps` | `vercel.write_session_files` | Retained native |
| `cua_repl` | `js_reset` | Retained native |
| `cua_repl` | `turn_ended` | Retained native |
| `event-stream` | `event_stream_start` | Retained native |
| `event-stream` | `event_stream_stop` | Retained native |
| `linear-graphql` | `archive_issue` | Retained native |
| `linear-graphql` | `graphql_mutation` | Retained native |
| `linear-graphql` | `restore_issue` | Retained native |
| `linear-graphql-avanza-control` | `archive_issue` | Retained native |
| `linear-graphql-avanza-control` | `graphql_mutation` | Retained native |
| `linear-graphql-avanza-control` | `restore_issue` | Retained native |
| `linear-graphql-tradeincode` | `archive_issue` | Retained native |
| `linear-graphql-tradeincode` | `graphql_mutation` | Retained native |
| `linear-graphql-tradeincode` | `restore_issue` | Retained native |
| `macbook-credential-broker` | `authorize_and_fill_credential` | Retained native |
| `macbook-credential-broker` | `run_credential_broker_self_test` | Retained native |
| `macbook-credential-broker` | `test_credential_approval_channel` | Retained native |
| `messages` | `send_message` | Retained native |
| `node_repl` | `js_add_node_module_dir` | Retained native |
| `node_repl` | `js_reset` | Retained native |
| `node_repl` | `turn_ended` | Retained native |

### Mixed (10)

| Server | Exact tool name | Disposition |
| --- | --- | --- |
| `codex_apps` | `codex_document_control.execute_document_command` | Retained native |
| `codex_apps` | `codex_security_cloud.open_defense_factory` | Retained native |
| `codex_apps` | `near_io_little_world.direct_near` | Retained native |
| `codex_apps` | `pets.validate_pet_spritesheet` | Retained native |
| `codex_apps` | `pro_brief_workspace.request_host_action` | Retained native |
| `codex_apps` | `pro_brief_workspace.run_command` | Retained native |
| `codex_apps` | `safety_settings.prepare_parental_control_update` | Retained native |
| `codex_apps` | `vercel.run_session_command` | Retained native |
| `cua_repl` | `js` | Retained native |
| `node_repl` | `js` | Retained native |

## Claude Chrome MCP

22 tools.

### Query (5)

| Server | Exact tool name | Disposition |
| --- | --- | --- |
| `claude-in-chrome` | `find` | URI page: `hypertui://tools/chrome/claude-in-chrome/find` |
| `claude-in-chrome` | `get_page_text` | URI page: `hypertui://tools/chrome/claude-in-chrome/get_page_text` |
| `claude-in-chrome` | `list_connected_browsers` | URI page: `hypertui://tools/chrome/claude-in-chrome/list_connected_browsers` |
| `claude-in-chrome` | `read_page` | URI page: `hypertui://tools/chrome/claude-in-chrome/read_page` |
| `claude-in-chrome` | `shortcuts_list` | URI page: `hypertui://tools/chrome/claude-in-chrome/shortcuts_list` |

### Mutation (10)

| Server | Exact tool name | Disposition |
| --- | --- | --- |
| `claude-in-chrome` | `file_upload` | Retained native |
| `claude-in-chrome` | `form_input` | Retained native |
| `claude-in-chrome` | `navigate` | Retained native |
| `claude-in-chrome` | `resize_window` | Retained native |
| `claude-in-chrome` | `select_browser` | Retained native |
| `claude-in-chrome` | `shortcuts_execute` | Retained native |
| `claude-in-chrome` | `switch_browser` | Retained native |
| `claude-in-chrome` | `tabs_close_mcp` | Retained native |
| `claude-in-chrome` | `tabs_create_mcp` | Retained native |
| `claude-in-chrome` | `upload_image` | Retained native |

### Mixed (7)

| Server | Exact tool name | Disposition |
| --- | --- | --- |
| `claude-in-chrome` | `browser_batch` | Retained native |
| `claude-in-chrome` | `computer` | Retained native |
| `claude-in-chrome` | `gif_creator` | Retained native |
| `claude-in-chrome` | `javascript_tool` | Retained native |
| `claude-in-chrome` | `read_console_messages` | Retained native |
| `claude-in-chrome` | `read_network_requests` | Retained native |
| `claude-in-chrome` | `tabs_context_mcp` | Retained native |

## Open Dot application tools

These application-local tools are not entries in the installed MCP catalog above.

| Tool | Class | Disposition |
| --- | --- | --- |
| `hyperTUI` | Query | Gateway native entry; worker backend also accepts this internally but does not advertise a second worker query entry. URI pages are read-only. |
| `present_ui` | Mutation | Retained native; creates or updates a conversation card. |
| `worker_list` | Query | Removed from native worker exposure and rejected as a direct call; use `hypertui://workers/`. |
| `worker_status` | Query | Removed from native worker exposure and rejected as a direct call; follow `hypertui://workers/<workerId>`. |
| `worker_start` | Mutation | Retained native; starts an independent worker. |
| `worker_submit` | Mutation | Retained native; submits an authorized assignment. |
| `worker_stop` | Mutation | Retained native; stops only the targeted worker. |
| `hyperTUI_action` | Mutation | Stable F/remote-adapter entry; validates a currently open page action and returns a redirect. The read-only query gateway does not advertise it. |

## Native harness and file-query boundaries

- Owned Claude speaker keeps its existing empty built-in tool set (`--tools ''`); its Chrome mutation/mixed tools remain as listed above.
- Owned Codex `view_image` is disabled in favor of PNG/JPEG/WebP file-image pages. An explicit absolute path, `file:///absolute/image.png`, or `hypertui://file/?path=ENCODED_ABSOLUTE_PATH` can read a regular file outside the workspace, subject to the same OS filesystem permissions and bounded file checks. Absolute-file pages do not list directories. Workspace browsing stays under `hypertui://files/`; escaping symlinks remain rejected there.
- Owned Codex native web search is disabled in favor of the cataloged `search_service.web_run` URI page.
- Shell/general execution and native mutation/mixed tools remain available. The ineffective code-mode-host trial was reverted.
- The active public manifest separately classifies native public orchestration tools, including `functions.request_user_input_async` as mutation. No claim is made that the current session was retroactively filtered.
