# Website Folder

This folder is the default source for the static infrastructure demo deployed by `scripts/start-demo.sh`.

## Default Site

`website/default-site` contains a small three-page HTML/CSS demo:

- `index.html`
- `services.html`
- `about.html`
- `assets/styles.css`

The launcher packages this folder into a zip file under `.generated/`, then Terraform passes that archive into the EC2 user-data script. During instance bootstrap, the archive is unpacked into `/var/www/html/demo`.

## Bring Your Own HTML

You can point the launcher at another static website folder when prompted:

```text
Static website folder path [/path/to/website/default-site]:
```

The folder must include an `index.html` file. Relative links, CSS, JavaScript, and image assets should live inside the same folder.

WordPress owns the site root `/` and remains editable from `/wp-admin/`.
