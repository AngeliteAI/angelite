use std::{
    pin::Pin,
    task::{Context, Poll},
};

pub use hyper::rt as hyper_rt;
use pin_project::pin_project;
pub struct Tokio;

impl<Fut: Future> hyper_rt::Executor<Fut> for Tokio
where
    Fut: Send + 'static,
    Fut::Output: Send + 'static,
{
    fn execute(&self, fut: Fut) {
        tokio::spawn(fut);
    }
}

pub struct Timer;

impl hyper_rt::Timer for Timer {
    fn sleep(&self, duration: std::time::Duration) -> std::pin::Pin<Box<dyn hyper_rt::Sleep>> {
        Box::pin(Sleep(tokio::time::sleep(duration)))
    }

    fn sleep_until(&self, deadline: std::time::Instant) -> std::pin::Pin<Box<dyn hyper_rt::Sleep>> {
        Box::pin(Sleep(tokio::time::sleep_until(
            tokio::time::Instant::from_std(deadline),
        )))
    }
}

#[pin_project]
pub struct Sleep(#[pin] tokio::time::Sleep);

impl hyper_rt::Sleep for Sleep {}

impl Future for Sleep {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        self.project().0.poll(cx)
    }
}

#[pin_project]
pub struct Io<T>(#[pin] pub(crate) T);

impl<T> hyper_rt::Read for Io<T>
where
    T: tokio::io::AsyncRead,
{
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        mut buf: hyper_rt::ReadBufCursor<'_>,
    ) -> Poll<Result<(), std::io::Error>> {
        let n = unsafe {
            let mut tbuf = tokio::io::ReadBuf::uninit(buf.as_mut());
            match tokio::io::AsyncRead::poll_read(self.project().0, cx, &mut tbuf) {
                Poll::Ready(Ok(())) => tbuf.filled().len(),
                other => return other,
            }
        };

        unsafe {
            buf.advance(n);
        }
        Poll::Ready(Ok(()))
    }
}

impl<T> hyper_rt::Write for Io<T>
where
    T: tokio::io::AsyncWrite,
{
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &[u8],
    ) -> Poll<Result<usize, std::io::Error>> {
        tokio::io::AsyncWrite::poll_write(self.project().0, cx, buf)
    }

    fn poll_flush(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Result<(), std::io::Error>> {
        tokio::io::AsyncWrite::poll_flush(self.project().0, cx)
    }

    fn poll_shutdown(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
    ) -> Poll<Result<(), std::io::Error>> {
        tokio::io::AsyncWrite::poll_shutdown(self.project().0, cx)
    }

    fn is_write_vectored(&self) -> bool {
        tokio::io::AsyncWrite::is_write_vectored(&self.0)
    }

    fn poll_write_vectored(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        bufs: &[std::io::IoSlice<'_>],
    ) -> Poll<Result<usize, std::io::Error>> {
        tokio::io::AsyncWrite::poll_write_vectored(self.project().0, cx, bufs)
    }
}
