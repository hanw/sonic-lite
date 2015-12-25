
#include "dmac.h"
#include "portal.h"
#include <GeneratedTypes.h>
#include <algorithm>
#include "dmaManager.h"
#include "DmaIndication.h"
#include "DmaRequest.h"

static int proxyNames[] = {
  IfcNames_DmaRequestS2H0,
  IfcNames_DmaRequestS2H1,
  IfcNames_DmaRequestS2H2,
  /*IfcNames_DmaRequestS2H3,
  IfcNames_DmaRequestS2H4,
  IfcNames_DmaRequestS2H5,
  IfcNames_DmaRequestS2H6,
  IfcNames_DmaRequestS2H7*/
};
static int wrapperNames[] = {
  IfcNames_DmaIndicationH2S0,
  IfcNames_DmaIndicationH2S1,
  IfcNames_DmaIndicationH2S2,
  /*IfcNames_DmaIndicationH2S3,
  IfcNames_DmaIndicationH2S4,
  IfcNames_DmaIndicationH2S5,
  IfcNames_DmaIndicationH2S6,
  IfcNames_DmaIndicationH2S7*/
};

DmaManager *mgr;
void initDmaManager()
{
#ifndef SIMULATION
//#warning
    noprogram = 1;
#endif
    if (!mgr)
	mgr = platformInit();
}


DmaBuffer::DmaBuffer(int size)
  : size(size), ref(-1)
{
    fd = portalAlloc(size, 1);
    buf = (char *)portalMmap(fd, size);
}

DmaBuffer::~DmaBuffer()
{
    dereference();
    portalMunmap(buf, size);
    close(fd);
}

uint32_t DmaBuffer::reference()
{
    initDmaManager();
    if (ref == -1)
	ref = mgr->reference(fd);
    return ref;
}

void DmaBuffer::dereference()
{
    if (ref != -1 && mgr)
	mgr->dereference(ref);
    ref = -1;
}

class DmaIndication : public DmaIndicationWrapper
{
    DmaChannel *channel;
    DmaCallback *callbacks;
public:
    DmaIndication(unsigned int id, PortalPoller *poller, DmaChannel *channel, DmaCallback *callbacks)
	: DmaIndicationWrapper(id, poller), channel(channel), callbacks(callbacks) {
    }

    void transferToFpgaDone ( uint32_t sglId, uint32_t base, const uint8_t tag, uint32_t cycles ) {
	if (callbacks)
	    callbacks->transferToFpgaDone(sglId, base, tag, cycles);
    }
    void transferFromFpgaDone ( uint32_t sglId, uint32_t base, uint8_t tag, uint32_t cycles ) {
	if (callbacks)
	    callbacks->transferFromFpgaDone(sglId, base, tag, cycles);
    }
};

DmaChannel::DmaChannel(int channel, DmaCallback *callbacks, bool singleThreadedAccess)
  : poller(new PortalPoller(0)), channel(channel), singleThreadedAccess(singleThreadedAccess)
{
    initDmaManager();
    if (!singleThreadedAccess)
	pthread_mutex_init(&channel_lock, 0);
    dmaRequest    = new DmaRequestProxy(proxyNames[channel], poller);
    dmaRequest->pint.busyType = BUSY_SPIN;
    dmaIndication = new DmaIndication(wrapperNames[channel], poller, this, callbacks);
    dmaRequest->writeRequestSize(128);
    dmaRequest->readRequestSize(256);
}

void DmaChannel::checkIndications()
{
    if (!singleThreadedAccess) pthread_mutex_lock(&channel_lock);
    void *rc = poller->pollFn(
#ifdef BOARD_bluesim
			      100
#else
-1
#endif
);
    if ((long) rc >= 0)
	poller->event();
    if (!singleThreadedAccess) pthread_mutex_unlock(&channel_lock);
}

int DmaChannel::transferToFpga ( const uint32_t objId, const uint32_t base, const uint32_t bytes, const uint8_t tag )
{
    if (!singleThreadedAccess) pthread_mutex_lock(&channel_lock);
    int v = dmaRequest->transferToFpga(objId, base, bytes, tag);
    if (!singleThreadedAccess) pthread_mutex_unlock(&channel_lock);
    return v;
}

int DmaChannel::transferFromFpga ( const uint32_t objId, const uint32_t base, const uint32_t bytes, const uint8_t tag )
{
    if (!singleThreadedAccess) pthread_mutex_lock(&channel_lock);
    int v = dmaRequest->transferFromFpga(objId, base, bytes, tag);
    if (!singleThreadedAccess) pthread_mutex_unlock(&channel_lock);
    return v;
}

int DmaChannel::setWriteRequestSize(int bytes)
{
  if (!singleThreadedAccess) pthread_mutex_lock(&channel_lock);
  this->writeRequestSize = std::min<int>(1024, bytes);
  dmaRequest->writeRequestSize(this->writeRequestSize);
  if (!singleThreadedAccess) pthread_mutex_unlock(&channel_lock);
  return this->writeRequestSize;
}

int DmaChannel::setReadRequestSize(int bytes)
{
  if (!singleThreadedAccess) pthread_mutex_lock(&channel_lock);
  this->readRequestSize = std::min<int>(1024, bytes);
  dmaRequest->readRequestSize(this->readRequestSize);
  if (!singleThreadedAccess) pthread_mutex_unlock(&channel_lock);
  return this->readRequestSize;
}
