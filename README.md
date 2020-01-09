# mount_photos

>  Mounting Google Photo albums with FUSE in Ada

This is a small demo how to use OAuth2 and Google API in Ada.
The program mounts Google Photo albums shared with you in
a local directory.

## Install

Run
```
gprbuild -p -P mount_photos.gpr
```

### Dependencies
It depends on [Matreshka](https://forge.ada-ru.org/matreshka) and
[Ada FUSE](https://github.com/medsec/ada-fuse/) libraries.

## Usage
Open a [Google Cloud Console](https://console.developers.google.com/) and create
a new project. Then create a authorization credentials as described
[here](https://developers.google.com/identity/protocols/OAuth2ForDevices).
Save client_id and secret.

Create a directory `~/.config/Matreshka Project` and file
`Mount Photos.conf` in it with content like this

```
[oauth]
client_id=<your client id>
client_secret=<corresponding secret>
```

To start app just run `./obj/main /tmp/photo` in a console,
where `/tmp/photo` is an empty directory to be mounted.

It will ask for Access_Token, just press Enter, because you don't
have it yet. It will point you to an URL where you can get
access code. Put access code in the console and application
exchanges it for access token. Next time you launch the
application can enter it at first question until it gets
expired.

To unmount the directory run

```
fusermount -u /tmp/photo
```

## Maintainer

[@MaximReznik](https://github.com/reznikmm).

## License

[MIT](LICENSE) © Maxim Reznik
