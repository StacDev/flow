# Vendored A2UI schemas — pending pin

This directory will hold the **vendored A2UI v0.9.x JSON schemas** (component
messages, data-model messages, `renderer_to_agent` egress) copied verbatim from
the upstream A2UI project at a pinned release/commit recorded here.

Not vendored yet: the pin (exact upstream tag + commit) is chosen at the start
of the M2 GenUI work, when the codec spike consumes these files — vendoring a
moving spec earlier would freeze an arbitrary snapshot nobody validates
against. Until then, nothing imports this directory.

When vendoring: copy files unmodified, record `UPSTREAM.md` with the source
URL, tag, commit hash, and licence, and never edit the vendored files — the
codec owns all adaptation.
