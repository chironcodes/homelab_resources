#!/usr/bin/env node
// xyOps Event Plugin: Generic API Ingestion
// Fetches JSON from any HTTP/HTTPS endpoint and passes the response downstream.
// Protocol: xyOps Wire Protocol v1 (JSON over STDIO)

'use strict';

const https = require('https');
const http = require('http');

function send(obj) {
	process.stdout.write(JSON.stringify(obj) + '\n');
}

function fetchJson(rawUrl) {
	const parsed = new URL(rawUrl);
	const lib = parsed.protocol === 'https:' ? https : http;

	return new Promise((resolve, reject) => {
		lib.get(rawUrl, res => {
			let body = '';
			res.on('data', chunk => body += chunk);
			res.on('end', () => {
				if (res.statusCode !== 200) {
					return reject(new Error(`API returned HTTP ${res.statusCode}`));
				}
				try { resolve(JSON.parse(body)); }
				catch { reject(new Error('API returned invalid JSON')); }
			});
		}).on('error', reject);
	});
}

function expandParams(str, params) {
	// Replace {key} placeholders with sibling param values.
	// Uses single braces to avoid conflict with xyOps's own {{ }} macro system
	// which resolves against upstream job output data, not sibling params.
	return str.replace(/\{(\w+)\}/g, (_, key) => params[key] ?? '');
}

async function main() {
	let raw = '';
	for await (const chunk of process.stdin) raw += chunk;

	const input = JSON.parse(raw);
	const params = input.params || {};
	const url = expandParams((params.url || process.env.PARAM_URL || '').trim(), params);

	if (!url) {
		send({ xy: 1, code: 1, description: 'Missing required parameter: url' });
		process.exit(1);
	}

	send({ xy: 1, status: `Fetching ${url}...` });

	const data = await fetchJson(url);

	send({ xy: 1, data });

	// Render key/value table for flat response objects
	if (data && typeof data === 'object' && !Array.isArray(data)) {
		const rows = Object.entries(data).map(([k, v]) => [k, String(v)]);
		send({
			xy: 1,
			table: {
				title: 'API Response',
				header: ['Key', 'Value'],
				rows,
				caption: url,
			},
		});
	}

	send({ xy: 1, code: 0 });
}

main().catch(err => {
	send({ xy: 1, code: 1, description: err.message });
	process.exit(1);
});
