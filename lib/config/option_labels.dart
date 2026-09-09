// Canonical variant "option type" labels (e.g. "Weight" for a 500g/1kg
// option row). Mirrored in src/lib/optionLabels.ts on the web app.
// The add/edit screen also allows a "Custom…" escape hatch for a stored
// value outside this list, so old free-text labels keep displaying/editing
// fine.
const List<String> kOptionLabels = ['Weight', 'Size', 'Colour', 'Pack', 'Quantity'];
