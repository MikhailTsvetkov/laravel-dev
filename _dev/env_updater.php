<?php
declare(strict_types=1);

// Replace dotenv assignments literally: values are data, never shell or regex code.
function envLines(string $text): array
{
    $text = preg_replace('/^\xEF\xBB\xBF/', '', $text);
    $lines = explode("\n", rtrim(str_replace(["\r\n", "\r"], "\n", $text), "\n"));
    foreach ($lines as $line) {
        if (!preg_match('/^\s*(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=\s*(.*)$/', $line, $match)) {
            continue;
        }
        $value = $match[1];
        if ($value === '' || ($value[0] !== '"' && $value[0] !== "'")) {
            continue;
        }
        $closed = false;
        for ($i = 1; $i < strlen($value); $i++) {
            if ($value[$i] === '\\') {
                $i++;
            } elseif ($value[$i] === $value[0]) {
                $closed = true;
                break;
            }
        }
        if (!$closed) {
            throw new RuntimeException('Multiline or unterminated quoted dotenv values are not supported.');
        }
    }
    return $lines;
}

function updateEnv(string $source, string $target): void
{
    if (!is_file($source) || !is_file($target) || is_link($target)) {
        throw new RuntimeException('Source and target must be existing regular .env files.');
    }
    $sourceText = file_get_contents($source);
    $targetText = file_get_contents($target);
    if ($sourceText === false || $targetText === false) {
        throw new RuntimeException('Cannot read .env files.');
    }
    $updates = [];
    foreach (envLines($sourceText) as $line) {
        if (trim($line) === '' || str_starts_with(ltrim($line), '#')) {
            continue;
        }
        if (!preg_match('/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$/', $line, $match)) {
            throw new RuntimeException('Unsupported dotenv line; use one KEY=value assignment per line.');
        }
        $updates[$match[1]] = $match[1] . '=' . $match[2];
    }
    $lines = envLines($targetText);
    $seen = [];
    foreach ($lines as &$line) {
        if (preg_match('/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/', $line, $match)
            && array_key_exists($match[1], $updates)) {
            $line = $updates[$match[1]];
            $seen[$match[1]] = true;
        }
    }
    unset($line);
    foreach (array_diff_key($updates, $seen) as $line) {
        $lines[] = $line;
    }
    $mode = fileperms($target);
    $temporary = tempnam(dirname($target), '.env-update-');
    if ($temporary === false) {
        throw new RuntimeException('Cannot create temporary .env file.');
    }
    try {
        $contents = implode("\n", $lines) . "\n";
        if (file_put_contents($temporary, $contents) !== strlen($contents)
            || $mode === false || !chmod($temporary, $mode & 0777)
            || !rename($temporary, $target)) {
            throw new RuntimeException('Cannot replace target .env file.');
        }
    } finally {
        if (is_file($temporary)) {
            unlink($temporary);
        }
    }
}

try {
    if ($argc !== 3) {
        throw new RuntimeException('Usage: php env_updater.php <source> <target>');
    }
    updateEnv($argv[1], $argv[2]);
} catch (Throwable $error) {
    fwrite(STDERR, $error->getMessage() . PHP_EOL);
    exit(1);
}
