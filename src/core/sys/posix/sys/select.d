/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.sys.select;

private import core.sys.posix.config;
public import core.stdc.time;           // for timespec
public import core.sys.posix.sys.time;  // for timeval
public import core.sys.posix.sys.types; // for time_t
public import core.sys.posix.signal;    // for sigset_t

//debug=select;  // uncomment to turn on debugging printf's
version(unittest) import core.stdc.stdio: printf;

extern (C):

//
// Required
//
/*
NOTE: This module requires timeval from core.sys.posix.sys.time, but timeval
      is supposedly an XOpen extension.  As a result, this header will not
      compile on platforms that are not XSI-compliant.  This must be resolved
      on a per-platform basis.

fd_set

void FD_CLR(int fd, fd_set* fdset);
int FD_ISSET(int fd, const(fd_set)* fdset);
void FD_SET(int fd, fd_set* fdset);
void FD_ZERO(fd_set* fdset);

FD_SETSIZE

int  pselect(int, fd_set*, fd_set*, fd_set*, in timespec*, in sigset_t*);
int  select(int, fd_set*, fd_set*, fd_set*, timeval*);
*/

version( linux )
{
    private
    {
        alias c_long __fd_mask;
        enum uint __NFDBITS = 8 * __fd_mask.sizeof;

        extern (D) auto __FDELT( int d )
        {
            return d / __NFDBITS;
        }

        extern (D) auto __FDMASK( int d )
        {
            return cast(__fd_mask) 1 << ( d % __NFDBITS );
        }
    }

    enum FD_SETSIZE = 1024;

    struct fd_set
    {
        __fd_mask[FD_SETSIZE / __NFDBITS] fds_bits;
    }

    extern (D) void FD_CLR( int fd, fd_set* fdset )
    {
        fdset.fds_bits[__FDELT( fd )] &= ~__FDMASK( fd );
    }

    extern (D) bool FD_ISSET( int fd, const(fd_set)* fdset )
    {
        return (fdset.fds_bits[__FDELT( fd )] & __FDMASK( fd )) != 0;
    }

    extern (D) void FD_SET( int fd, fd_set* fdset )
    {
        fdset.fds_bits[__FDELT( fd )] |= __FDMASK( fd );
    }

    extern (D) void FD_ZERO( fd_set* fdset )
    {
        fdset.fds_bits[0 .. $] = 0;
    }

    /+
     + GNU ASM Implementation
     +
    # define __FD_ZERO(fdsp)                                \
      do {                                                  \
        int __d0, __d1;                                     \
        __asm__ __volatile__ ("cld; rep; stosl"             \
                  : "=c" (__d0), "=D" (__d1)                \
                  : "a" (0), "0" (sizeof (fd_set)           \
                          / sizeof (__fd_mask)),            \
                    "1" (&__FDS_BITS (fdsp)[0])             \
                  : "memory");                              \
      } while (0)

    # define __FD_SET(fd, fdsp)                             \
      __asm__ __volatile__ ("btsl %1,%0"                    \
                : "=m" (__FDS_BITS (fdsp)[__FDELT (fd)])    \
                : "r" (((int) (fd)) % __NFDBITS)            \
                : "cc","memory")
    # define __FD_CLR(fd, fdsp)                             \
      __asm__ __volatile__ ("btrl %1,%0"                    \
                : "=m" (__FDS_BITS (fdsp)[__FDELT (fd)])    \
                : "r" (((int) (fd)) % __NFDBITS)            \
                : "cc","memory")
    # define __FD_ISSET(fd, fdsp)                           \
      (__extension__                                        \
       ({register char __result;                            \
         __asm__ __volatile__ ("btl %1,%2 ; setcb %b0"      \
                   : "=q" (__result)                        \
                   : "r" (((int) (fd)) % __NFDBITS),        \
                     "m" (__FDS_BITS (fdsp)[__FDELT (fd)])  \
                   : "cc");                                 \
         __result; }))
     +/

    int pselect(int, fd_set*, fd_set*, fd_set*, in timespec*, in sigset_t*);
    int select(int, fd_set*, fd_set*, fd_set*, timeval*);
}
else version( OSX )
{
    private
    {
        enum uint __DARWIN_NBBY    = 8;                            /* bits in a byte */
        enum uint __DARWIN_NFDBITS = (int.sizeof * __DARWIN_NBBY); /* bits per mask */
    }

    enum FD_SETSIZE = 1024;

    struct fd_set
    {
        int[(FD_SETSIZE + (__DARWIN_NFDBITS - 1)) / __DARWIN_NFDBITS] fds_bits;
    }

    extern (D) void FD_CLR( int fd, fd_set* fdset )
    {
        fdset.fds_bits[fd / __DARWIN_NFDBITS] &= ~(1 << (fd % __DARWIN_NFDBITS));
    }

    extern (D) bool FD_ISSET( int fd, const(fd_set)* fdset )
    {
        return (fdset.fds_bits[fd / __DARWIN_NFDBITS] & (1 << (fd % __DARWIN_NFDBITS))) != 0;
    }

    extern (D) void FD_SET( int fd, fd_set* fdset )
    {
        fdset.fds_bits[fd / __DARWIN_NFDBITS] |= 1 << (fd % __DARWIN_NFDBITS);
    }

    extern (D) void FD_ZERO( fd_set* fdset )
    {
        fdset.fds_bits[0 .. $] = 0;
    }

    int pselect(int, fd_set*, fd_set*, fd_set*, in timespec*, in sigset_t*);
    int select(int, fd_set*, fd_set*, fd_set*, timeval*);
}
else version( FreeBSD )
{
    private
    {
        alias c_ulong __fd_mask;
        enum _NFDBITS = __fd_mask.sizeof * 8;
    }

    enum uint FD_SETSIZE = 1024;

    struct fd_set
    {
        __fd_mask __fds_bits[(FD_SETSIZE + (_NFDBITS - 1)) / _NFDBITS];
    }

    extern (D) __fd_mask __fdset_mask(uint n)
    {
        return cast(__fd_mask) 1 << (n % _NFDBITS);
    }

    extern (D) void FD_CLR( int n, fd_set* p )
    {
        p.__fds_bits[n / _NFDBITS] &= ~__fdset_mask(n);
    }

    extern (D) bool FD_ISSET( int n, const(fd_set)* p )
    {
        return (p.__fds_bits[n / _NFDBITS] & __fdset_mask(n)) != 0;
    }

    extern (D) void FD_SET( int n, fd_set* p )
    {
        p.__fds_bits[n / _NFDBITS] |= __fdset_mask(n);
    }

    extern (D) void FD_ZERO( fd_set* p )
    {
        fd_set *_p;
        size_t _n;

        _p = p;
        _n = (FD_SETSIZE + (_NFDBITS - 1)) / _NFDBITS;
        while (_n > 0)
            _p.__fds_bits[--_n] = 0;
    }

    int pselect(int, fd_set*, fd_set*, fd_set*, in timespec*, in sigset_t*);
    int select(int, fd_set*, fd_set*, fd_set*, timeval*);
}

unittest
{
    debug(select) printf("core.sys.posix.sys.select unittest\n");

    fd_set fd;

    for (auto i = 0; i < FD_SETSIZE; i++)
    {
        assert(!FD_ISSET(i, &fd));
    }

    for (auto i = 0; i < FD_SETSIZE; i++)
    {
        if ((i & -i) == i)
            FD_SET(i, &fd);
    }

    for (auto i = 0; i < FD_SETSIZE; i++)
    {
        if ((i & -i) == i)
            assert(FD_ISSET(i, &fd));
        else
            assert(!FD_ISSET(i, &fd));
    }

    for (auto i = 0; i < FD_SETSIZE; i++)
    {
        if ((i & -i) == i)
            FD_CLR(i, &fd);
        else
            FD_SET(i, &fd);
    }

    for (auto i = 0; i < FD_SETSIZE; i++)
    {
        if ((i & -i) == i)
            assert(!FD_ISSET(i, &fd));
        else
            assert(FD_ISSET(i, &fd));
    }

    FD_ZERO(&fd);

    for (auto i = 0; i < FD_SETSIZE; i++)
    {
        assert(!FD_ISSET(i, &fd));
    }
}

