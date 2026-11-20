import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { marked } from 'marked';

test('tenant-controlled GPO cells render as literal text, never links or images', () => {
	const root = fileURLToPath(new URL('../../../', import.meta.url));
	const text = '<&|[x](https://evil.example) ![x](https://evil.example/p.png) https://evil.example www.evil.example a@b.example\nnext';
	const encoded = Buffer.from(text).toString('base64');
	const script = `$ErrorActionPreference='Stop'; Import-Module ./powershell/Maester.psd1; & (Get-Module Maester) { $text=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encoded}')); Format-MtAdGpoResult -Summary 'Inventory' -Details @([pscustomobject]@{Name=$text}) -Properties Name }`;
	const markdown = execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], { cwd: root, encoding: 'utf8', timeout: 30000 });
	const html = marked.parse(markdown, { gfm: true });
	assert.doesNotMatch(html, /<a\b|<img\b/i);
	assert.match(html, /<td>/);
	assert.match(html, /&lt;&amp;\|\[x\]\(https:\/\/evil\.example\)/);
	assert.match(html, /www\.evil\.example a@b\.example next/);
	assert.doesNotMatch(html, /\\&(?:lt|amp|#124);/);
});
