#include "ns3/applications-module.h"
#include "ns3/core-module.h"
#include "ns3/flow-monitor-module.h"
#include "ns3/internet-module.h"
#include "ns3/network-module.h"
#include "ns3/ping-helper.h"
#include "ns3/point-to-point-module.h"
#include "ns3/traffic-control-module.h"
#include "ns3/trace-helper.h"

#include <string>

using namespace ns3;

void
RttTracer(ns3::Ptr<ns3::OutputStreamWrapper> stream, unsigned short seq, ns3::Time rtt)
{
    *stream->GetStream() << ns3::Simulator::Now().GetSeconds()
                         << "\t"
                         << seq
                         << "\t"
                         << rtt.GetMilliSeconds()
                         << std::endl;
}

// New tracer to record bytes in the queue (accept old and new values)
void
BytesInQueueTracer(Ptr<OutputStreamWrapper> stream, uint32_t oldBytes, uint32_t newBytes)
{
    *stream->GetStream() << Simulator::Now().GetSeconds()
                         << "\t"
                         << newBytes
                         << std::endl;
}


int
main(int argc, char* argv[])
{
    int simulationTime = 20;
    std::string queueDiscType = "ns3::FifoQueueDisc";

    CommandLine cmd;
    cmd.AddValue("typeQueueDisc", "Type of queue disc: ns3::FifoQueueDisc, ns3::CoDelQueueDisc, ns3::RedQueueDisc, etc.", queueDiscType);
    cmd.Parse(argc, argv);


    // Nodes
    NodeContainer sources, sink, router;
    sources.Create(2);   // h1, h2
    sink.Create(1);      // h3
    router.Create(2);    // R1, R2

    // LAN on left bottom: h2, R1
    NodeContainer lanLeftDown;
    lanLeftDown.Add(sources.Get(1));
    lanLeftDown.Add(router.Get(0)); 

    // LAN on left top: h1, R1
    NodeContainer lanLeftUp;
    lanLeftUp.Add(sources.Get(0));
    lanLeftUp.Add(router.Get(0));

    PointToPointHelper p2pRegular;
    p2pRegular.SetDeviceAttribute("DataRate", StringValue("5Mbps"));
    p2pRegular.SetChannelAttribute("Delay", StringValue("1ms"));

    // install for left lans up and down
    NetDeviceContainer leftUpDevices = p2pRegular.Install(lanLeftUp);
    NetDeviceContainer leftDownDevices = p2pRegular.Install(lanLeftDown);

    // install p2p Bottleneck R1 ↔ R2
    PointToPointHelper p2pBottleneck;
    p2pBottleneck.SetDeviceAttribute("DataRate", StringValue("1Mbps"));
    p2pBottleneck.SetChannelAttribute("Delay", StringValue("3ms"));
    NetDeviceContainer midDevices = p2pBottleneck.Install(router.Get(0), router.Get(1));

    // LAN on right: R2, h3
    NodeContainer lanRight;
    lanRight.Add(router.Get(1));
    lanRight.Add(sink.Get(0));

    // install p2p for right lan
    NetDeviceContainer rightDevices = p2pRegular.Install(lanRight);

    // Install protocols
    InternetStackHelper internet;
    internet.Install(sources);
    internet.Install(sink);
    internet.Install(router);

    // Install queue-disc on R1 side of bottleneck BEFORE assigning IPs to the devices.
    // TrafficControlLayer is available after InternetStackHelper::Install.
    TrafficControlHelper tch;
    tch.SetRootQueueDisc(queueDiscType);
    NetDeviceContainer r1DevContainer;
    r1DevContainer.Add(midDevices.Get(0)); // R1 side of the bottleneck
    QueueDiscContainer qdiscs = tch.Install(r1DevContainer);
    Ptr<QueueDisc> r1QueueDisc = (qdiscs.GetN() > 0) ? qdiscs.Get(0) : nullptr;

    // Assign subnets (must happen after installing non-default queue-disc)
    Ipv4AddressHelper address;
    address.SetBase("10.0.0.0", "255.255.255.0");
    Ipv4InterfaceContainer leftUpIf = address.Assign(leftUpDevices);

    address.SetBase("10.1.0.0", "255.255.255.0");
    Ipv4InterfaceContainer leftDownIf = address.Assign(leftDownDevices);

    address.SetBase("10.2.0.0", "255.255.255.0");
    Ipv4InterfaceContainer midIf = address.Assign(midDevices);

    address.SetBase("10.3.0.0", "255.255.255.0");
    Ipv4InterfaceContainer rightIf = address.Assign(rightDevices);

    // Create trace output streams once and attach traces
    AsciiTraceHelper ascii;
    Ptr<OutputStreamWrapper> rttStream = ascii.CreateFileStream("ping-rtt.txt");
    Ptr<OutputStreamWrapper> queueStream = ascii.CreateFileStream("queue-bytes.txt");

    if (r1QueueDisc)
    {
        r1QueueDisc->TraceConnectWithoutContext("BytesInQueue",
            MakeBoundCallback(&BytesInQueueTracer, queueStream));
    }

    Ipv4GlobalRoutingHelper::PopulateRoutingTables();

    OnOffHelper onoff("ns3::UdpSocketFactory",
                      InetSocketAddress(rightIf.GetAddress(1), 5000)); // h3 IP
    onoff.SetConstantRate(DataRate("2Mbps"), 1000); // 2 Mbps, 1000-byte packets
    ApplicationContainer app1 = onoff.Install(sources.Get(0)); // h1
    app1.Start(Seconds(5.0));
    app1.Stop(Seconds(15.0));

    PacketSinkHelper sinkHelper("ns3::UdpSocketFactory",
                                InetSocketAddress(Ipv4Address::GetAny(), 5000));
    ApplicationContainer sinkApp = sinkHelper.Install(sink.Get(0)); // h3

    PingHelper pingHelper(rightIf.GetAddress(1));
    pingHelper.SetAttribute("Interval", TimeValue(Seconds(1.0)));
    pingHelper.SetAttribute("Size", UintegerValue(56));
    ApplicationContainer pingApp = pingHelper.Install(sources.Get(1)); // h2
    pingApp.Start(Seconds(0.0));
    pingApp.Stop(Seconds(simulationTime));

    sinkApp.Start(Seconds(5.0));
    sinkApp.Stop(Seconds(15.0));

    // Bind the stream as the first parameter of RttTracer
    pingApp.Get(0)->TraceConnectWithoutContext("Rtt",
        MakeBoundCallback(&RttTracer, rttStream));

    Simulator::Schedule(Seconds(simulationTime), [simulationTime]() {
        std::cout << "Simulation reached " << simulationTime << " seconds" << std::endl;
    });

    std::cout << "Starting Simulation" << std::endl;
    Simulator::Stop(Seconds(simulationTime));
    Simulator::Run();
    Simulator::Destroy();

    return 0;
}
