# PMM 1.3.0 RC24 — UI and Fix Lab deployment isolation

Build ID: `PMM-v1.3.0-RC24-UI-FIXLAB-DEPLOYMENT-ISOLATION`

RC24 is a focused correction over RC23. It preserves the complete RC19 functional base, the RC21 UI/detection/cache reconciliation, RC22 effective-conflict patch reuse and Semiauto migration, and the RC23 Windows PowerShell 5.1 singleton-array guards.

## Corrected behavior

### Header resizing

RC23 placed the title in a star-sized column between the logo and a minimum-width action column. Near the minimum usable width or across a DPI transition, the title could be squeezed almost to zero. Its wrapping subtitle then measured as a very tall one-character-wide block, making the automatic header row occupy nearly the entire window.

RC24 gives the three-line title a stable 245-DIP column and lets the action area stretch and wrap. The logo, title, tabs and workspace must remain visible throughout normal resizing.

### Fix Lab responsiveness

- Selecting Fix Lab now returns from `SelectionChanged` before module/dashboard hydration.
- Expanding Advanced queues its hydration after WPF paints the expanded card; collapsing it performs no refresh.
- Dashboard state is cached for sixty seconds during navigation.
- Candidate discovery uses one library/backup snapshot rather than two full discovery passes and repeated ignored-source JSON reads.
- **Refresh Fix Lab** is always visible in the Fix Lab header for explicit on-demand refresh.

### Compatibility-merge ownership

The user's RC23 transaction `20260829_224602_6209239d` proved that Deploy Fix backed up and retired both:

- `zzzzzzzzzz_PMM_Merge_20260829_223524_P.pak`;
- its `.manifest.json` sidecar.

Restore contained the same obsolete overlay-retirement policy. RC24 removes both paths and applies the ownership rule globally: Fix Lab Apply/Restore and source-mod deletion may change source PAKs and invalidate Analyze freshness, but they do not remove, replace, back up, clear or deselect a deployed compatibility merge.

The unused legacy `Restore-PMMDeployment` entry point was also removed so there is no non-UI bulk-undeploy route left in the runtime.

Only explicit actions in **Compatibility patches** may change that merge:

1. Deploy with a selected saved patch;
2. choose **No compatibility patch** and Deploy;
3. UNDEPLOY;
4. Delete merge.

## Windows acceptance

1. Resize RC24 continuously from the normal layout to the minimum width and move it between monitors/scaling levels if available. The header must never consume the whole workspace.
2. Open Fix Lab. The tab must paint before its dashboard refresh begins.
3. Expand and collapse section 6 repeatedly. The visual state must change immediately; use **Refresh Fix Lab** to request current disk state explicitly.
4. Deploy a known compatibility merge and record the SHA-256 of its PAK and sidecar.
5. Apply a Gura repair. Both merge files must remain present and byte-identical.
6. Restore the original Gura v5 source. Both merge files must again remain present and byte-identical.
7. Delete/disable an unrelated source mod. The merge remains physically deployed; Analyze may mark source freshness stale and can safely reuse/reselect it when the effective conflict proof still matches.

Cross-platform validation cannot execute the Windows WPF/PowerShell 5.1 host or Palworld. Do not promote RC24 to final until this acceptance passes on the target machine.
