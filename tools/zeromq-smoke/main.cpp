#include <zmq.hpp>

int main()
{
    zmq::context_t context { 1 };
    return context.handle() == nullptr ? 1 : 0;
}
