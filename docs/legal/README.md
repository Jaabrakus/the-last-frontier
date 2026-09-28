# Legal: the licence, the notices and takedowns

Drafts written 2026-09-27 at the owner's request: legal terms forbidding reverse engineering, data mining and AI
training, backed by copyright and takedown notices. **None of this is legal advice.** Have a qualified lawyer review
every file here before the game is sold or distributed, and fill in every `[BRACKETED]` item.

## The files

| File | What it is | Where it shows |
| --- | --- | --- |
| `EULA.txt` | The End User Licence Agreement: the licence to play, what players may not do (reverse engineering, extraction, data mining, AI training, redistribution), videos and streams allowed, the text-and-data-mining reservation, no warranty, liability limits | Shipped with the game; the main menu's Credits screen shows it in full |
| `NOTICE.txt` | The short copyright notice with the no-AI-training / data-mining reservation | Shipped with the game; the top of the Credits screen |
| `docs/legal/takedown_notice.md` | A DMCA-style takedown notice template for stores, hosts and platforms | For the owner's use only; not shipped |

## To fill in before release

- `[STUDIO OR OWNER LEGAL NAME]`: the person or company that owns the game and signs licences.
- `[YEAR]` and `[DATE]`.
- `[COUNTRY / STATE]`: the governing law. A lawyer should pick this; consumer protection rules differ by country.
- `[LEGAL CONTACT EMAIL OR ADDRESS]`: where legal notices go. Consider a dedicated address rather than a personal one.

## Things a lawyer should look at

- **CC-BY and other open-licence assets.** Section 2 keeps their licences in force and their credits intact, as the
  licences require.
- **Public-domain paintings.** The EULA claims no rights in them. The game's own painted views and selection are
  ours.
- **Reverse-engineering bans.** Some laws, such as the EU Software Directive's interoperability exception, allow
  limited decompiling whatever a licence says. Section 3's "except where the law expressly allows it" keeps the clause
  enforceable where it can be.
- **Consumer law.** Warranty and liability limits are restricted for consumers in many countries (the EU, the UK,
  Australia). Section 10 preserves non-waivable rights, but a lawyer should tailor sections 8 and 9.
- **Stores.** Steam and other stores can show a EULA at purchase or first launch. Decide whether this one is shown
  there as well.

## Shipping note

The game reads `CREDITS.md`, `EULA.txt` and `NOTICE.txt` at run time (the Credits screen). When an export preset is
made, add `*.md, *.txt` to "Filters to export non-resource files" so they ship inside the game. Without that, the
Credits screen falls back to a short line.

## Beyond the paperwork

The licence works best with the technical and practical measures discussed alongside it:
- an encrypted game pack (Godot's AES-256 export encryption with custom export templates);
- no secrets in the client;
- server-authoritative multiplayer;
- `noai` tags and AI-crawler blocks on the game's website.
