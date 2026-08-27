#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main (int argc, char* argv[])
{
    char* file = argv[1];
    int fd;
    int exitcode;
    struct flock lock;

    printf ("opening %s\n", file);
    /* Open a file descriptor to the file. */
    fd = open (file, O_WRONLY);
    printf ("locking\n");
    /* Initialize the flock structure. */
    memset (&lock, 0, sizeof(lock));
    lock.l_type = F_WRLCK;
    /* Place a write lock on the file. */
    exitcode = fcntl (fd, F_SETLK, &lock);

    if(exitcode == 0){
    printf ("Acquired lock, retaining for a minute\n"); 
    sleep(60);
    printf ("unlocking\n");
    /* Release the lock. */
    lock.l_type = F_UNLCK;
    fcntl (fd, F_SETLK, &lock);
    close (fd);
    return 0;
    }
    else{
    printf ("Unable to acquire lock\n");
    return (EXIT_FAILURE); 
    }
}