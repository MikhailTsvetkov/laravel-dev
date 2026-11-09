<?php
declare(strict_types=1);

try {
    $root = dirname(__DIR__);
    $staging = $root . '/laravel-dev';
    $entries = array_values(array_diff(scandir($staging) ?: [], ['.', '..']));
    if (!in_array('composer.json', $entries, true)) {
        throw new RuntimeException('Laravel staging directory is incomplete.');
    }
    // Check every collision before moving anything. Wrapper settings take precedence.
    $merged = [];
    foreach ($entries as $entry) {
        $target = $root . '/' . $entry;
        if (!file_exists($target) && !is_link($target)) {
            continue;
        }
        if (is_link($target) || !is_file($target) || !in_array($entry, ['.env', '.gitignore', '.gitattributes'], true)) {
            throw new RuntimeException("Installation conflict: $entry already exists. Staging was kept in laravel-dev.");
        }
        if ($entry !== '.env') {
            // Existing attributes/ignore rules go last so they retain precedence.
            $merged[$entry] = rtrim(file_get_contents($staging . '/' . $entry))
                . "\n\n# Project wrapper rules\n" . file_get_contents($target);
        }
    }
    foreach ($merged as $entry => $contents) {
        if (file_put_contents($staging . '/' . $entry, $contents) === false) {
            throw new RuntimeException("Cannot merge $entry.");
        }
    }
    // Preserve the application's PHP constraint; Composer already checked compatibility.
    foreach ($entries as $entry) {
        $source = $staging . '/' . $entry;
        $target = $root . '/' . $entry;
        if ($entry === '.env' && is_file($target) && !chmod($source, fileperms($target) & 0777)) {
            throw new RuntimeException('Cannot preserve .env permissions.');
        }
        if (!rename($source, $target)) {
            throw new RuntimeException("Cannot move $entry; remaining files are in laravel-dev.");
        }
    }
    if (!rmdir($staging)) {
        throw new RuntimeException('Cannot remove empty laravel-dev directory.');
    }
} catch (Throwable $error) {
    fwrite(STDERR, $error->getMessage() . PHP_EOL);
    exit(1);
}
