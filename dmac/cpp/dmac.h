
#include <pthread.h>
#include <semaphore.h>
#include <stdint.h>

class DmaManager;

class DmaBuffer {
    const int size;
    int fd;
    char *buf;
    int ref;
public:
    // Allocates a portal memory object of specified size and maps it into user process
    DmaBuffer(int size);
    // Dereferences and deallocates the portal memory object
    // if destructor is not called, the object is automatically
    // unreferenced and freed when the process exits
    ~DmaBuffer();
    // returns the address of the mapped buffer
    char *buffer() {
	return buf;
    }
    // returns the reference to the object
    //
    // Sends the address translation table to hardware MMU if necessary.
    uint32_t reference();
    // Removes the address translation table from the hardware MMU
    void dereference();
};

// Implement DmaCallback to receive notifications that DMA transferToFpga and transferFromFpga requests are done
class DmaCallback {
public:
    DmaCallback() {}
    virtual ~DmaCallback() {}
    //  DmaChannel calls transferToFpgaDone from DmaChannel::checkIndications when it is notified that a DMA transferToFpga request has completed
    virtual void transferToFpgaDone ( uint32_t sglId, uint32_t base, const uint8_t tag, uint32_t cycles ) = 0;
    //  DmaChannel calls transferFromFpgaDone from DmaChannel::checkIndications when it is notified that a DMA transferFromFpga request has completed
    virtual void transferFromFpgaDone ( uint32_t sglId, uint32_t base, uint8_t tag, uint32_t cycles ) = 0;
};

class DmaIndication;
class DmaRequestProxy;
class PortalPoller;

// DmaChannel provides thread safe access to DMA channel number channelnum and
// it notifies the client of completion of requests via the callbacks object
class DmaChannel {
  pthread_mutex_t channel_lock;
  PortalPoller *poller;
  DmaIndication *dmaIndication;
  DmaRequestProxy *dmaRequest;
  int channel;
  volatile int waitCount;
  bool singleThreadedAccess;
  int writeRequestSize;
  int readRequestSize;
  friend class DmaIndication;
  friend class DmaController;
  static void *threadfn(void *c);
public:
    DmaChannel(int channelnum, DmaCallback *callbacks = 0, bool singleThreadedAccess = true);
    // check for notification of completion of DMA requests
    void checkIndications();
    // issue a DMA transferToFpga request
    int transferToFpga ( const uint32_t objId, const uint32_t base, const uint32_t bytes, const uint8_t tag );
    // issue a DMA transferFromFpga request
    int transferFromFpga ( const uint32_t objId, const uint32_t base, const uint32_t bytes, const uint8_t tag );
    // change writeRequestSize
    int setWriteRequestSize(int writeRequest);
    // change readRequestSize
    int setReadRequestSize(int readRequest);
};
