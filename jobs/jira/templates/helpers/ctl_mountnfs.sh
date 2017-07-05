function mount_nfs {
    #BLOCK: Mount home directory, unmount it if mounted, then mount it
    if mountpoint -q -- "$MOUNTPOINT"; then
      umount $MOUNTPOINT -lf
    fi
    mount <%= p('jira.nfs_ip_server')%>:<%= p('jira.nfs_share_folder')%> $MOUNTPOINT -o nolock
    #ENDBLOCK: Mounting data directory
}

function umount_nfs {
    #BLOCK: Mount home directory, unmount it if mounted, then mount it
    if mountpoint -q -- "$MOUNTPOINT"; then
      umount $MOUNTPOINT -lf
    fi
}
